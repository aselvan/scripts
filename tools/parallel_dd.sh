#!/usr/bin/env bash
#
# parallel_dd.sh --- Run dd in parallel to copy image to multiple devices
#
# The assumption here is that if we run dd in parallel the throughput can 
# be much better than running in serial i.e. one by one if the destination 
# devices are on separage USB bus so they don't compete for I/O.
#
# Required: tee, dd, pv (for progress install with "apt-get|brew install pv")
#
# Author:  Arul Selvan
# Created: May 10, 2024
#
# Version History:
#   May 10, 2024 --- Original version
#   May 12, 2024 --- Validate the output devices before using
#   May 24, 2024 --- Fix GPT size mismatch, send mail optionally, -f to skip confirmation
#   May 26, 2024 --- Added resize partition to fill, and extend NTFS to end of partition.
#   Jun 12, 2024 --- Added option to write a tag/version file on new imaged disk
#

# version format YY.MM.DD
version=24.06.12
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Run dd in parallel to copy image to multiple devices."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
my_name_noext="$(echo $my_name|cut -d. -f1)"

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:l:s:e:t:fxvh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

device_list=""
image_file=""
dd_bs="32"
failure=0
skip_confirmation=0
extend_ntfs=0
tag=""

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -i <image>  ---> The disk image to write to multiple devices 
  -l <list>   ---> list of output devices write image
  -s <size>   ---> buffer size (megabyte) argument for dd [default: $dd_bs]
  -e <email>  ---> email address to send success/failure emails
  -t <string> ---> A tag string to inlcude in /$my_name_noext.txt [default: no file written]
  -f          ---> skip confirmation question for automated runs from cron.
  -x          ---> extend the NTFS volume (assuming image is NTFS and last partion is NTFS) [default: NO]
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -i myimage.iso -l "/dev/sdb /dev/sdb /dev/sdc" -e foo@bar.com
  
EOF
  exit 0
}

mail_and_exit() {
  log.stat "Total runtime: $(elapsed_time)"
  log.stat "Exit Status: $failure"
  send_mail "$failure"
  exit $failure
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
    log.error "Unable to find the last partition on $dev ... skiping tag file"
    return
  fi

  # create a mount point in /tmp and mount the disk
  mount_dir="/tmp/$my_name_noext"
  mkdir $mount_dir

  # mount the disk
  log.stat "Mounting ${dev}${pnum} on $mount_dir ..."
  mount ${dev}${pnum} $mount_dir
  if [ $? -ne 0 ] ; then
    log.error "Mount failed... skipping tag file ..."
    return
  fi

  # write the tag file
  log.stat "Writing tag/version file on root directory of ${dev}${pnum} ..."
  cat << EOF > ${mount_dir}/${my_name_noext}.txt
  
  Imaging Tool: $my_version
  Image Tag:    $tag
  Image Date:   `date`
  
EOF
  # now unmount
  umount $mount_dir
}

#
# validate if the device list is indeed a real one. For files
# we just check if path is valid
#
validate_devices() {
  for d in $device_list ; do
    if [[ "$d" = "/dev/"* ]]; then
      df $d >/dev/null 2>&1
      if [ $? -eq 0 ] ; then
        log.debug "  Device: '$d' is a valid device"
        continue
      else
        log.error "  Device: '$d' is an invalid device!"
        exit 2
      fi
    else
      if [ -w "`dirname $d`" ]; then
        log.debug "  Device: '$d' is a file path and dir is writable!"
        continue
      else
        log.error "  Device: '$d' is invalid file/path!"
        exit 3
      fi
    fi
  done
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
    i)
      image_file="$OPTARG"
      ;;
    l)
      device_list="$OPTARG"
      ;;
    s)
      dd_bs="$OPTARG"
      ;;
    e)
      email_address=$OPTARG
      ;;
    t)
      tag="$OPTARG"
      ;;
    f)
      skip_confirmation=1
      ;;
    x)
      extend_ntfs=1
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

# check required args
if [ -z "$image_file" ] || [ -z "$device_list" ] ; then
  log.error "Missing required arguments! See usage below"
  usage
fi

validate_devices

# set correct flag for buffer size depending on MacOS or Linux
if [ "$os_name" = "Darwin" ] ; then
  dd_bs="${dd_bs}m"
else
  dd_bs="${dd_bs}M"
fi

# construct dd chain for parallel run
dd_chain=""
for dev in $device_list ; do
  dd_chain="$dd_chain >(dd of=$dev bs=$dd_bs >>$my_logfile 2>&1)"
done

# capture output of tee going to stdout to dev/null
dd_chain="$dd_chain | dd of=/dev/null >/dev/null 2>&1"

# confirm to proceed. Optionally, skip confirmation for automated runs
if [ $skip_confirmation -eq 0 ] ; then
  confirm_action "WARNING: writing to \"$device_list\""
  if [ $? -eq 0 ] ; then
    log.warn "Aborting..."
    exit 1
  fi
fi

# finally execute dd in parallel.
# note: we need to do in subshell to avoid shell interpreting and messing things up
log.stat "Running ..."
full_command="pv $image_file | tee $dd_chain"
/usr/bin/env bash -c "$full_command" 2>&1 >> $my_logfile
if [ $? -ne 0 ] ; then
  failure=1
  log.error "Failure during flashing $image_file ..."
  mail_and_exit
fi
log.stat "Success: all disks are flashed with the content of $image_file"

# note we need to skip if the destination is file but we can do that later.
log.stat "Fixing GPT mismatch ..."
for dev in $device_list ; do
  log.stat "  Adjust device: $dev"
  fix_gpt_mismatch $dev
done

# if se need to extend the disk and NTFS filesystems
if [ $extend_ntfs -ne 0 ] ; then
  for dev in $device_list ; do
    log.stat "  Extend the partition and NTFS file system of: $dev"
    extend_ntfs_partition $dev
  done
fi

# write tag/version file
if [ ! -z "$tag" ] ; then
  for dev in $device_list ; do
    log.stat "  Writing tag file on for: $dev"
    write_tag_file $dev
  done
fi

mail_and_exit

