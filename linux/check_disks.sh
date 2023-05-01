#!/bin/bash
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

# version format YY.MM.DD
version=19.06.23
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="u:e:cvh"
verbose=0
email_address=""
subject="$host_name: disk check SUCCESS"
subject_failed="$host_name: disk check FAILED"
failure=0
# UUID: from "ls -al /dev/disk/by-uuid"
uuid_list="638c3c50-6f6f-4b2b-b407-437c7074602b f5b39d74-5541-4478-b705-9762f7d3110c e087431d-84b8-404f-8de2-a3785f692426 acbc7081-368e-4459-b7b9-58f821665890"
uuid_path="/dev/disk/by-uuid"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -u <uuid_list> ---> double quoted list of space separated uuid's i.e. 'ls /dev/disk/by-uuid'
     -e <email>     ---> optional email address to mail results [default: '$email_address']
     -c             ---> validate all uuids [default: $uuid_list] 
     -v             ---> verbose mode prints info messages, otherwise just errors are printed
     -h             ---> print usage/help

  example: $my_name -u "$uuid_list" -e foo@bar.com -v
  
EOF
  exit 0
}

write_log() {
  local msg_type=$1
  local msg=$2

  # log info type only when verbose flag is set
  if [ "$msg_type" == "[INFO]" ] && [ $verbose -eq 0 ] ; then
    return
  fi

  echo "$msg_type $msg" | tee -a $log_file
}

init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "[STAT]" "$my_version"
  write_log "[STAT]" "Running from: $my_path"
  write_log "[STAT]" "Start time:   `date +'%m/%d/%y %r'` ..."
}


check_os() {
  if [ $os_name != "Linux" ] ; then
    write_log "[ERROR]" "This script is meant for Linux OS only!"
    exit 1
  fi
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "root access needed to run this script, run with 'sudo $my_name'"
    exit 2
  fi
}

# validate single uuid
validate_uuid() {
  local uuid=$1
  disk_dev=`/usr/bin/readlink -nf  $uuid_path/$uuid`
  
  write_log "[INFO]" "validating uuid: $uuid ..."
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

  write_log "[INFO]" "validating uuids ..."
  for uuid in $uuid_list ; do
    validate_uuid $uuid
    if [ $? -ne 0 ]; then
      write_log "[WARN]" "UUID ($uuid) is invalid!"      
      atleast_one_failed=1
    fi
  done
  exit $atleast_one_failed
}

# Check and make sure the device is not mounted, if mounted state, attempt to 
# unmount and return 0 if it is successfully unmounted.
unmount_device() {
  local uuid=$1
  write_log "[INFO]" "Checking mount status ..."
  /usr/bin/findmnt UUID=$uuid >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    write_log "[INFO]" "Device was in mounted state, so attempting to unmount..." 
    umount UUID=$uuid >> $log_file 2>&1
    return $?
  fi
  write_log "[INFO]" "Device was not in mounted state." 
  return 0
}

# ----------  main --------------
init_log
check_os
check_root

# parse commandline options
while getopts "$options_list" opt ; do
  case $opt in
    c)
      validate_uuids
      ;;
    u)
      uuid_list="$OPTARG"
      ;;
    e)
      email_address="$OPTARG"
      echo "$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    h|?|*)
      usage
      ;;
  esac
done


write_log "[INFO]" "Host: $host_name"
for uuid in $uuid_list ; do
  write_log "[STAT]" "==================== device: $uuid ==================== "

  # check if device is valid disk
  validate_uuid $uuid
  if [ $? -ne 0 ] ; then
    write_log "[WARN]" "skipping invalid uuid ($uuid) ..."     
    failure=1
    continue
  fi

  # check and make sure device is in unmounted state
  unmount_device $uuid
  if [ $? -ne 0 ] ; then
    write_log "[WARN]" "Device failed to unmount, skipping device $uuid" 
    failure=1
    continue
  fi
  
  write_log "[INFO]" "Ensured device is not mounted, proceeding to check ..."
  
  # now do a e2fsck on this device
  write_log "[STAT]" "Running e2fsck ..."
  # note: -p to automatically fix, or error out with error message and non-zero exit code
  /sbin/e2fsck -p UUID=$uuid >> $log_file 2>&1
  rc=$?
  if [ $rc -ne 0 ] ; then
    write_log "[ERROR]" "e2fsck failed, error code = $rc, skipping device $uuid"
    failure=1
    continue
  fi

  # reset mount counts
  write_log "[STAT]" "Resetting mount count/max ..." 
  /sbin/tune2fs -C0 -c64 UUID=$uuid >> $log_file 2>&1
  if [ $verbose -eq 1 ] ; then
    /sbin/tune2fs -l UUID=$uuid |grep -i "mount count" >> $log_file 2>&1
  fi
done

# email the results if email address provided
if [ ! -z $email_address ] ; then  
  write_log "[INFO]" "Emailing results ..."
  if [ $failure -eq 0 ] ; then
    /bin/cat $log_file | /usr/bin/mail -s "$subject" $email_address
  else
    /bin/cat $log_file | /usr/bin/mail -s "$subject_failed" $email_address
  fi
fi
