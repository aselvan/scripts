#!/usr/bin/env bash
#
# disk_copy.sh --- Copy a disk partition by partition for making clone w/ disk_clone.sh
#
# Required: pv, sfdisk (install by apt-get install pv sfdisk)
# OS: Linux only
# Author:  Arul Selvan
# Created: Jul 14, 2024
#
# See Also:
#   disk_clone.sh
#
# Version History:
#   Jul 14, 2024 --- Original version
#


# version format YY.MM.DD
version=24.07.14
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Copy a disk partition by partion for making clone w/ disk_clone.sh."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
my_name_noext="$(echo $my_name|cut -d. -f1)"

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="d:p:vh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

device=""
disk_copy_dir=${DISK_COPY_DIR:-"/opt/cftb/images"}
dd_bs="64K"

usage() {
  cat << EOF
  
$my_name --- $my_title

Usage: $my_name [options]
  -d <device> ---> The device to make a copy.
  -p <path>   ---> dirctory path to save copied disk components [Default: $disk_copy_dir]
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -d /dev/sdd -p $disk_copy_dir
  
EOF
  exit 0
}

#
# Validate if the device is indeed a real one. Also ensure all partitions 
# in that device are unmounted.
#
validate_device() {
  df $device >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    log.debug "  $device is a valid device"
    log.stat  "  Unmounting any mounted partions on $device ..."
    unmount_all_partitions $device
    return
  else
    log.error "  Device: $device is an invalid device!"
    exit 2
  fi
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
    d)
      device="$OPTARG"
      ;;
    p)
      disk_copy_dir="$OPTARG"
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
if [ -z "$device" ] ; then
  log.error "  Missing device name argument! See usage below"
  usage
fi

if [ ! -w $disk_copy_dir ] ; then
  log.error "  The directory path ($disk_copy_dir) is either non-existent or wriable"
  usage
fi

# check device is good and unmount any mounted partitions
validate_device

# ----- Start copy ---------

# copy the mbr/gpt header
log.stat "  Copying GPT/MBR headers ..."
dd if=$device of=${disk_copy_dir}/mbr_gpt.dat bs=512 count=2048 >> $my_logfile 2>&1

# copy the partition table
log.stat "  Copying partition table layout ..."
sfdisk --dump $device >${disk_copy_dir}/partition.tab 

# get list of partitions
partition_list=$(ls ${device}* | grep -o '[0-9]*$')

# copy each of the partitions to a separate file
log.stat "  Copying all partition data ..."
for p in $partition_list; do
  log.stat "    Copying partition: ${device}${p} ..."
  dd if=${device}${p} of=${disk_copy_dir}/partition${p}.dat conv=noerror,sync status=progress bs=$dd_bs 2>&1 | tee -a $my_logfile
done

log.stat "$my_name completed in $(elapsed_time)"

