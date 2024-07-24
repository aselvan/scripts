#!/usr/bin/env bash
#
# disk_clone.sh --- Clone multiple disks in parallel using dd
#
# The assumption here is that if we run dd in parallel the throughput can 
# be much better than running in serial i.e. one by one if the destination 
# devices are on separage USB bus so they don't compete for I/O.
#
# Required: pv, sfdisk (install by apt-get install pv sfdisk)
# OS: Linux 
# Author:  Arul Selvan
# Created: May 10, 2024
#
# See Also:
#   disk_copy.sh
#
# Version History:
#   May 10, 2024 --- Original version 
#   May 12, 2024 --- Validate the output devices before using
#   May 24, 2024 --- Fix GPT size mismatch, send mail optionally, -f to skip confirmation
#   May 26, 2024 --- Added resize partition to fill, and extend NTFS to end of partition.
#   Jun 13, 2024 --- Added option to write a tag/version file on new imaged disk(s)
#   Jun 18, 2024 --- Added code to ensure all partitions on target device are umounted.
#   Juy 15, 2024 --- Renamed (was parallel_dd.sh) and now uses images created by disk_copy.sh
#   Juy 17, 2024 --- Reordered tag file creation and also make a copy to disk_copy_dir
#   Juy 19, 2024 --- Flush OS cache after each disk operations, option to copy files to root dir
#   Juy 24, 2024 --- Optionally, copy a directory to root dir of the target disk
#

# version format YY.MM.DD
version=24.07.24
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Clone multiple disks in parallel using dd."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
my_name_noext="$(echo $my_name|cut -d. -f1)"
tag_file="/tmp/${my_name_noext}.txt"

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:l:e:t:c:fvh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

disk_copy_dir=${DISK_COPY_DIR:-"/opt/cftb/images"}
dd_bs="64K"
gpt_mbr_file=mbr_gpt.dat
partition_table_file=partition.tab

device_list=""
failure=0
skip_confirmation=0
extend_ntfs=0
tag="CFTB image (`date +'%b %d, %r'`)"
partition_file_count=0
dir_to_copy=""
mount_dir="/tmp/$my_name_noext"


usage() {
  cat << EOF

$my_name --- $my_title

Usage: $my_name [options]
  -p <path>   ---> directory where disk components are saved by disk_copy.sh [Default: $disk_copy_dir]
  -l <list>   ---> list of output devices to write [example: "/dev/sdc /dev/sdd"]
  -e <email>  ---> email address to send success/failure emails
  -t <string> ---> A tag string to inlcude in /$my_name_noext.txt
  -c <subdir> ---> Copy all the files from $disk_copy_dir/<subdir> to root drive of target device
  -f          ---> skip confirmation question for automated runs from cron.
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -p $disk_copy_dir -l "/dev/sdc /dev/sdd /dev/sde" -e foo@bar.com -f
  
EOF
  exit 0
}

mail_and_exit() {
  log.debug "Exit Status: $failure"
  send_mail "$failure"
  log.stat "$my_name completed in $(elapsed_time)"
  exit $failure
}

create_tag_file() {
  cat << EOF > ${tag_file}
  
  Imaging Tool:  $my_version
  Source:        https://github.com/aselvan/scripts/blob/master/tools/disk_clone.sh
  GitHub:        https://github.com/aselvan/scripts
  Image Tag:     $tag
  Date created:  `date +'%b %d, %r'`
  
EOF
}

sync_os_cache() {
  # just sync OS
  log.stat "  Sync'ing OS cache to storage devices ..."
  sync
}

copy_dir() {
  local dev=$1
  if [ -z "$dir_to_copy" ] ; then
    log.debug "  No optional directory specified to copy"
    return
  fi

  # check if the directory exists and readable
  local dpath="${disk_copy_dir}/${dir_to_copy}"
  if [ ! -d "$dpath" ] || [ ! -r "$dpath" ] ; then
    log.warn "  Directory $dpath does not exists or readable, skipping..."
    return
  fi

  # finally copy
  log.stat "  Copying $dpath to root drive of target device ${dev}${pnum}"
  cp -rp ${dpath} ${mount_dir}/.
}

write_tag_file() {
  local dev=$1
  if [ -z "$dev" ] ; then
    log.error "Missing device!"
    return
  fi

  # find last partition
  local pnum=$(parted -s $dev print | awk '$1 ~ /^[0-9]+$/ { last = $1 } END { print last }')
  if [ -z "$pnum" ]; then
    log.error "  Unable to find the last partition on $dev ... skiping tag file"
    return
  fi

  # create a mount point in /tmp and mount the disk
  mkdir -p $mount_dir

  # mount the disk
  log.stat "  Mounting ${dev}${pnum} on $mount_dir ..."
  mount ${dev}${pnum} $mount_dir
  if [ $? -ne 0 ] ; then
    log.error "  Mount failed... skipping tag file ..."
    return
  fi

  # write the tag file
  log.stat "  Writing tag/version file on root directory of ${dev}${pnum} ..."
  cp  ${tag_file} ${mount_dir}/.
  copy_dir $dev

  # now unmount
  umount $mount_dir
  sync_os_cache
}

#
# Validate if the device list is indeed a real one. Also ensure all partitions 
# in that device are unmounted.
#
validate_devices() {
  for d in $device_list ; do
    df $d >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      log.debug "  $d is a valid device"
      log.stat  "  Unmounting any mounted partions on $d ..."
      unmount_all_partitions $d
      continue
    else
      log.error "  Device: $d is an invalid device!"
      exit 2
    fi
  done
}

validate_disk_copy_dir() {
  if [ ! -r $disk_copy_dir ] ; then
    log.error "  The directory path ($disk_copy_dir) is either non-existent or un-readable"
    usage
  fi

  # validate if it contains files we need to clone (previously created by disk_copy.sh)
  if [ ! -f ${disk_copy_dir}/mbr_gpt.dat ] ; then
    log.error "  Missing GPT/MBR header file: ${disk_copy_dir}/${gpt_mbr_file}"
    exit 3
  fi
  if [ ! -f ${disk_copy_dir}/partition.tab ] ; then
    log.error "  Missing partition table layout file: <D-c>${disk_copy_dir}/${partition_table_file}"
    exit 4
  fi

  # we expect at least one or more partition files present
  partition_file_count=`ls ${disk_copy_dir}/partition?.dat 2>/dev/null |wc -l`
  if [ $partition_file_count -le 0 ] ; then
    log.error "  Required partition data files missing in ${disk_copy_dir}"
    exit 5
  fi
}

copy_gpt_mbr() {
  log.stat "  Copy GPT/MBR on all devices"
  for dev in $device_list ; do
    log.stat "    Device: $dev"
    dd if=${disk_copy_dir}/${gpt_mbr_file} of=$dev >> $my_logfile 2>&1
  done
  sync_os_cache
}

copy_partition_table() {
  log.stat "  Creating partition table layout on all devices"
  for dev in $device_list ; do
    log.stat "    Device: $dev"
    cat ${disk_copy_dir}/${partition_table_file} | sfdisk $dev >> $my_logfile 2>&1
  done
  sync_os_cache
}

copy_all_partitions() {
  log.stat "  Copy partition data on all devices (be patient, will take long time)"
  
  # loop through each partition file and copy to all disks in parallel
  for (( p=1; p <= partition_file_count; p++ )) do
    partition_file=${disk_copy_dir}/partition${p}.dat
    log.stat "    Writing $partition_file"

    # construct dd chain for parallel run for this partitition
    dd_chain=""
    for dev in $device_list ; do
      dd_chain="$dd_chain >(dd of=${dev}${p} bs=$dd_bs >> $my_logfile 2>&1)"
    done

    # capture output of tee going to stdout to dev/null
    dd_chain="$dd_chain | dd of=/dev/null >/dev/null 2>&1"

    # finally execute dd in parallel.
    # note: we need to do in subshell to avoid shell interpreting and messing things up
    full_command="pv $partition_file | tee $dd_chain"
    log.debug "    Parallel copy command: $full_command"
    /usr/bin/env bash -c "$full_command"  2>&1 >> $my_logfile
    if [ $? -ne 0 ] ; then
      failure=1
      log.error "    ERROR: failed writing partition!"
      mail_and_exit
    fi
  done

  # just sync OS
  sync_os_cache
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    p)
      disk_copy_dir="$OPTARG"
      ;;
    l)
      device_list="$OPTARG"
      ;;
    e)
      email_address=$OPTARG
      ;;
    t)
      tag="$OPTARG"
      ;;
    c)
      dir_to_copy="$OPTARG"
      ;;
    f)
      skip_confirmation=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for root, pv etc
check_root
check_installed pv
check_installed sfdisk

# check required args
if [ -z "$device_list" ] ; then
  log.error "  Missing list of devices to clone! See usage below"
  usage
fi

validate_disk_copy_dir
validate_devices

# confirm to proceed. Optionally, skip confirmation for automated runs
if [ $skip_confirmation -eq 0 ] ; then
  confirm_action "WARNING: writing to \"$device_list\""
  if [ $? -eq 0 ] ; then
    log.warn "  Aborting..."
    exit 1
  fi
fi

# The following 2 tasks doesn't take much time so no need to be "in parallel"
copy_gpt_mbr
copy_partition_table

# now copy each of the partition data in parallel
copy_all_partitions

# create the tagfile and copy to all target devices
create_tag_file

# Finally, write tag/version
for dev in $device_list ; do
  log.stat "  Writing tag file on $dev"
  write_tag_file $dev
done

# save tag file 
cp ${tag_file} ${disk_copy_dir}/.

mail_and_exit
