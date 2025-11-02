#!/usr/bin/env bash
#
# check_disks.sh --- script to check Linux mountable disks and reset mount counts
#
# This script checks the mountable disks connected and active on Linux host for any
# errors, and resets mount count. Roughtly similar to what happens when Linux OS 
# boots. Primarily intended for external storage (usb, sata) devices as they get 
# mounted/unmounted often, at least in my system on a weekly basis to do backup. 
# The script ensures the device is in "unmounted" state before attempting to check
# or change mount counts. If disk is busy or unmount was not successful, it skips 
# the disk check on that device.
#
# Feel free to use it after changing the UUIDs to match your system. The following
# is my cron entry sample.
#
# # check disks every 60 days (at 2.13am on first day of every other month)
# 13 02 1 */2 *  $HOME/src/scripts.github/linux/check_disks.sh >/tmp/check_disks_cron.log 2>&1
#
# NOTE: Obviously, this script is meant for running under Linux. Also, you need
#       tune2fs utility installed (apt-get install e2fsprogs)
# 
#
# Author:  Arul Selvan
# Created: Jun 23, 2019
#
# Version History
#   19.06.23 --- Original version
#   24.05.01 --- Updated to use common logging includes
#   25.11.02 --- Fixed broken device id and added switch to rotate deveice list
#

# version format YY.MM.DD
version=25.11.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Script to check mountable disks and reset mount counts"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="u:e:l:cvh"

email_address=""
failure=0
# UUID: from "ls -al /dev/disk/by-uuid"
# NOTE: keep rotating (*420f23d7e68a & *58e406aaef5d) everytime we move the last device to offsite i.e. fireproof vault
uuid_list_1="638c3c50-6f6f-4b2b-b407-437c7074602b f5b39d74-5541-4478-b705-9762f7d3110c e087431d-84b8-404f-8de2-a3785f692426 489609f7-87f3-4ab0-94e1-420f23d7e68a"
uuid_list_2="638c3c50-6f6f-4b2b-b407-437c7074602b f5b39d74-5541-4478-b705-9762f7d3110c e087431d-84b8-404f-8de2-a3785f692426 5204ef97-f3f1-46cc-8a80-58e406aaef5d"
uuid_list="$uuid_list_1"

uuid_path="/dev/disk/by-uuid"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"


usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -u <uuid_list> ---> double quoted list of space separated uuid's i.e. 'ls /dev/disk/by-uuid'
  -e <email>     ---> optional email address to mail results
  -l <listid>    ---> 1 or 2 [default: 1]
  -c             ---> validate all uuids 
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

example(s): 
  $my_name -e foo@bar.com -v
  $my_name -l2 -c -e foo@bar.com -v
  $my_name -u "uuid1 uuid2 uuid3" -e foo@bar.com -v
  
EOF
  exit 0
}

check_os() {
  if [ $os_name != "Linux" ] ; then
    log.error "This script is meant for Linux OS only!"
    exit 1
  fi
}

# validate single uuid
validate_uuid() {
  local uuid=$1
  disk_dev=`/usr/bin/readlink -nf  $uuid_path/$uuid`
  
  log.stat "validating uuid: $uuid"
  if [ ! -b $disk_dev ] ; then
    return 1
  else
    return 0
  fi
}

# validate all uuids
validate_uuids() {
  local atleast_one_failed=0
  local uuid=""

  for uuid in $uuid_list ; do
    validate_uuid $uuid
    if [ $? -ne 0 ]; then
      log.warn "  Invalid/non-existent uuid: $uuid"      
      atleast_one_failed=1
    fi
  done
  exit $atleast_one_failed
}

# Check and make sure the device is not mounted, if mounted state, attempt to 
# unmount and return 0 if it is successfully unmounted.
unmount_device() {
  local uuid=$1
  log.stat "Checking mount status ..."
  /usr/bin/findmnt UUID=$uuid >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    log.stat "Device was in mounted state, so attempting to unmount..." 
    umount UUID=$uuid >> $my_logfile 2>&1
    return $?
  fi
  log.stat "Device was not in mounted state." 
  return 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts "$options_list" opt ; do
  case $opt in
    c)
      validate_uuids
      ;;
    u)
      uuid_list="$OPTARG"
      ;;
    l)
      if [ "$OPTARG" -eq 1 ] ; then
        uuid_list="$uuid_list_1"
      elif [ "$OPTARG" -eq 2 ] ; then
        uuid_list="$uuid_list_2"
      else
        log.warn "Invalid list_id ($OPTARG), continue with using default uuid_list."
      fi
      ;;
    e)
      email_address="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    h|?|*)
      usage
      ;;
  esac
done

check_os
check_root

log.stat "Host: $host_name"
log.debug "Using uuid_list: $uuid_list"

for uuid in $uuid_list ; do
  log.stat "==================== device: $uuid ==================== "

  # check if device is valid disk
  validate_uuid $uuid
  if [ $? -ne 0 ] ; then
    log.warn "skipping invalid uuid ($uuid) ..."     
    failure=1
    continue
  fi

  # check and make sure device is in unmounted state
  unmount_device $uuid
  if [ $? -ne 0 ] ; then
    log.warn "Device failed to unmount, skipping device $uuid" 
    failure=1
    continue
  fi
  log.stat "Ensured device is not mounted, proceeding to check ..."
  
  # now do a e2fsck on this device
  log.stat "Running e2fsck ..."
  # note: -p to automatically fix, or error out with error message and non-zero exit code
  /sbin/e2fsck -p UUID=$uuid >> $my_logfile 2>&1
  rc=$?
  if [ $rc -ne 0 ] ; then
    log.error "e2fsck failed, error code = $rc, skipping device $uuid"
    failure=1
    continue
  fi

  # reset mount counts
  log.stat "Resetting mount count/max ..." 
  /sbin/tune2fs -C0 -c64 UUID=$uuid >> $my_logfile 2>&1
  if [ $verbose -eq 1 ] ; then
    /sbin/tune2fs -l UUID=$uuid |grep -i "mount count" >> $my_logfile 2>&1
  fi
done

# mail and exit
log.stat "Disk check/reset complete."
log.stat "Total runtime: $(elapsed_time)"
send_mail "$failure"
