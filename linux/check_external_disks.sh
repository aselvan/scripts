#!/bin/bash
#
#
# check_external_disks.sh --- wrapper scripts to check external disks attached to a Linux server
#
# This script runs on a cron job every month to check i.e. fsck all the external disks and resets
# mount counts.
#
#
# Author:  Arul Selvan
# Version: Jun 23, 2019
# 
# TODO: The following are my server detatils for my reference, replace it to match yours
# --------------------------------------------------------------------------------------
# crontab entry
# # check disks every 60 days (at 2.13am on first day of every other month)
# 13 02 1 */2 *  $HOME/src/scripts.github/linux/check_external_disks.sh >/tmp/check_external_disks_cron.log 2>&1
#
# details on devices as per 'ls -al /dev/disk/by-uuid'
#
#  System HD Devices:
#  ------------------
#  53ae14f1-7461-4f8b-9544-dfb4a3585871 -> sda1 --> 2TB came w/ system
#  ea202984-2c37-4512-839d-37b9a0aad4e2 -> sdb1 --> 2TB WD enterprise drive added
#  b9492af0-5046-40cd-bfb9-a0c06596c0bf -> sdc2 --> 1TB came w/ system;instlled ubuntu 19.04 on /
# 
#  External HD Devices:
#  --------------------
# 638c3c50-6f6f-4b2b-b407-437c7074602b -> sdd1 ---> USB 1TB on /media/usb-1tb-2
# f5b39d74-5541-4478-b705-9762f7d3110c -> sde1 ---> USB 1TB on /media/usb-1tb-3 (recent Oct 19,2020)
# e087431d-84b8-404f-8de2-a3785f692426 -> sdf3 ---> RAID5 4TB on /media/sata-3tb (partition 3)
# 740ba660-8a88-3129-b99a-741302d7c2fd -> sdf2 ---> Part of RAID disk partition 2 (not used in backup)
# 67E3-17ED                            -> sdf1 ---> Part of RAID disk partiion 1 (not used in backup)
# --------------------------------------------------------------------------------------

options_list="hve:u:"
my_name=`basename $0`
my_host=`hostname`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
my_email=""
subject="Host: $my_host disk check"
subject_failed="Host: $my_host disk check FAILED"
failure=0
uuid_path="/dev/disk/by-uuid"
uuid_list="638c3c50-6f6f-4b2b-b407-437c7074602b f5b39d74-5541-4478-b705-9762f7d3110c e087431d-84b8-404f-8de2-a3785f692426"

usage() {
  echo "Usage: $my_name [-v] [-e <email>] [-u <uuid_list>]"
  echo "  -u <uuid_list> list of uuids to check, default: $uuid_list"
  echo "  -v validate all uuids are still good and are associated with disks"
  echo "  -e <email> email address to send the disk check status"
  echo "  -h usage"
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting." | /usr/bin/tee -a $log_file
    exit 1
  fi
}

# validate single uuid
validate_uuid() {
  local uuid=$1
  disk_dev=`/usr/bin/readlink -nf  $uuid_path/$uuid`
  
  echo -n "[INFO] validating uuid: $uuid ..." | /usr/bin/tee -a $log_file
  if [ ! -b $disk_dev ] ; then
    echo | /usr/bin/tee -a $log_file
    echo  "[ERROR] uuid ($uuid) is not pointing to a valid disk device!" | /usr/bin/tee -a $log_file
    return 1
  else
    echo " valid" | /usr/bin/tee -a $log_file
    return 0
  fi
}

# validate all uuids
validate_uuids() {
  local atleast_one_failed=0
  local uuid=""

  echo "[INFO] validating uuids ..." | /usr/bin/tee -a $log_file
  for uuid in $uuid_list ; do
    validate_uuid $uuid
    if [ $? -ne 0 ]; then
      atleast_one_failed=1
    fi
  done
  exit $atleast_one_failed
}


# check and make sure the device is not mounted
# returns 1 if device is unmounted, 0 when unmount failed
unmount_device() {
  local uuid=$1
  echo "[INFO] Checking mount status ..." | /usr/bin/tee -a $log_file
  /usr/bin/findmnt UUID=$uuid >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    echo "[INFO] Device was in mounted state, so attempting to unmount..." | /usr/bin/tee -a $log_file
    /usr/bin/umount UUID=$uuid >> $log_file 2>&1
    return $?
  fi
  echo "[INFO] Device was not in mounted state." | /usr/bin/tee -a $log_file
  return 0
}

# check drives and reset mount count
check_reset_drives() {
  local uuid=""
  for uuid in $uuid_list ; do
    echo "==================== device: $uuid ==================== " | /usr/bin/tee -a $log_file

    # check if its valid disk 
    validate_uuid $uuid
    if [ $? -ne 0 ] ; then
      failure=1
      continue
    fi

    # check and make sure device is in unmounted state
    unmount_device $uuid
    if [ $? -ne 0 ] ; then
      echo "[WARN] Device failed to unmount, skipping this device" | /usr/bin/tee -a $log_file
      failure=1
      continue
    fi
  
    echo "[INFO] Ensured device is not mounted, proceeding to check ..." | /usr/bin/tee -a $log_file
    # now do a e2fsck on this device
    echo "[INFO] Running e2fsck ..." | /usr/bin/tee -a $log_file
    # note: -p to automatically fix, or error out with error message and non-zero exit code
    /sbin/e2fsck -p UUID=$uuid 2>&1 | /usr/bin/tee -a $log_file
    rc=$?
    if [ $rc -ne 0 ] ; then
      echo "[ERROR] e2fsck failed, error code = $rc, error message should be above this line" | /usr/bin/tee -a $log_file
      failure=1
    fi

    # reset mount counts
    echo "[INFO] Resetting mount count/max for device: uuid" | /usr/bin/tee -a $log_file
    /sbin/tune2fs -C0 -c64 UUID=$uuid 2>&1 | /usr/bin/tee -a $log_file
    /sbin/tune2fs -l UUID=$uuid |grep -i "mount count"  2>&1 | /usr/bin/tee -a $log_file
  done
}

# --------------- main ----------------------
echo "[INFO] `date`: $my_name starting ..." > $log_file
echo "[INFO] Host: $my_host" | /usr/bin/tee -a $log_file
echo "[INFO] Run date: `date`" | /usr/bin/tee -a  $log_file
check_root

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    v)
      validate_uuids
      ;;
    e)
      my_email=$OPTARG
      ;;
    u)
      uuid_list=$OPTARG
      ;;
    h)
      usage
      ;;
  esac
done

# check
echo "[INFO] disk check starting ..." | /usr/bin/tee -a $log_file
check_reset_drives
echo "[INFO] disk check done." | /usr/bin/tee -a  $log_file

# email the results
if [ ! -z $my_email ]; then
  echo "[INFO] e-mail results to $my_email" |/usr/bin/tee -a  $log_file  
  if [ $failure -eq 0 ] ; then
    /bin/cat $log_file | /usr/bin/mail -s "$subject" $my_email
  else
    /bin/cat $log_file | /usr/bin/mail -s "$subject_failed" $my_email
  fi
fi

exit 0
