#!/bin/bash
#
# onedrive_rsync.sh
#   Wrapper script to backup data to onedrive using rclone mount.
#
# Prereq: rclone must be installed
#
# Note: by default this script assumes rclone is configured with onedrive root as "[onedrive]" as 
#   shown below or you can specify a different label using -l <label> option.
#
# [onedrive]
# type = onedrive
# token = {"access_token":"zQrtZltT5ln5aFElma+hUKt9K1pL0a0R....}
#
# Author:  Arul Selvan
# Version: Aug 21, 2022
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=22.08.21
my_name=`basename $0`
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
rclone_opt="--vfs-cache-mode writes --vfs-cache-max-age 5m --vfs-cache-max-size 64M"

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="e:l:p:s:m:h"

# rsync options
# note: -a option contains -l and -D so we use no-XXX to remove them as we don't need them
rsync_opts="-azqt -O --no-links --no-D --delete --inplace --cvs-exclude --exclude=*.html --exclude=*.htm --exclude=*.backup --exclude=*.m3u --exclude=*.sh --exclude=thumb --exclude=jdothumb --exclude=*.exe --exclude=*.EXE --delete-excluded"

# backup locations
photos_src="/var/www/photos"
videos_src="/var/www/video"
src_dirs="$photos_src $videos_src"

onedrive_label="onedrive"
mount_point="/mnt/onedrive"
onedrive_root_path="/personal/home/media"
subject_success="OneDrive rsync success"
subject_failed="OneDrive rsync failed"
email_address=
onedrive_mounted=0
onedrive_mount_wait=10

usage() {
  echo "Usage: $my_name [options]"
  echo "  -s <source> one or more source directories to backup [default: \"$src_dirs\"]"
  echo "  -p <path> onedrive root path starting from label [$onedrive_label] to mount [default: $onedrive_root_path]"
  echo "  -l <label> onedrive label from rclone.conf [default: $onedrive_label]"
  echo "  -m <mount_point>  local mount point to mount onedrive [default: $mount_point]"
  echo "  -e <email_address> email address to send status"
  echo "  -h help"
  exit 0
}

mail_and_exit() {
  subject="$1"
  if [ ! -z $email_address ] ; then
    echo "[INFO] sending email to $email_address ..." >> $log_file
    cat $log_file | mail -s "$subject" $email_address
  else
    echo "[WARN] no e-mail address provided, skiping mail." >> $log_file
  fi
  exit
}

is_mounted() {
  if [ $os_name = "Darwin" ] ; then
    if mount | grep "on $mount_point" > /dev/null; then
      return 0
    else
      return 1
    fi
  else
    mountpoint -q "$mount_point"
    return $?
  fi
}

check_onedrive() {
  # make sure mount point exists
  mkdir -p $mount_point
  
  # mount onedrive if not mounted already
  is_mounted
  if [ $? -ne 0 ]; then
    echo "[INFO] OneDrive is not mounted, attempting to mount..." >> $log_file

    rclone $rclone_opt mount $onedrive_label:$onedrive_root_path $mount_point --daemon
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "[ERROR] mounting OneDrive, exiting, error = $rc" >> $log_file
      exit
    fi

    # wait few sec to check the drive mount again
    echo "[INFO] Waiting for $onedrive_mount_wait sec for OneDrive to mount..." >> $log_file
    /bin/sync
    sleep $onedrive_mount_wait 

    is_mounted
    if [ $? -ne 0 ]; then
      echo "[ERROR] Unable to mount OneDrive... giving up!" >> $log_file
      exit
    fi
    onedrive_mounted=1
  fi
  echo "[INFO] OneDrive is mounted and ready..." >> $log_file
}

unmount_onedrive() {
  echo "[INFO] unmounting OneDrive..." >> $log_file 
  
  # just do a couple of syncs to flush buffers
  sync
  sync

  # unmount only if we mounted it in the first place
  if [ $onedrive_mounted -eq 0 ]; then
    echo "[INFO] OneDrive was already mounted when we started, so leaving it mounted" >> $log_file
    return
  fi

  fusermount -u $mount_point
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "[INFO] onedrive unmount success" >> $log_file
  else
    echo "[ERROR] unmounting onedrive, error = $rc" >> $log_file
  fi 
}

# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    e)
      email_address=$OPTARG
      ;;
    l)
      onedrive_label=$OPTARG
      ;;
    p)
      onedrive_root_path=$OPTARG
      ;;
    m)
      mount_point=$OPTARG
      ;;
    s)
      src_dirs=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

echo "[INFO] $my_version " > $log_file
echo "[INFO] Start timestamp: `date`" >> $log_file

# check for onedrive availability
check_onedrive

# start rsync
echo "[INFO] Backup of '$src_dirs' starting at: `date +%r`" >> $log_file
rsync $rsync_opts $src_dirs ${mount_point}/. >>$log_file 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "[ERROR] while rsync; error = $rc ... terminating." >> $log_file
  unmount_onedrive
  mail_and_exit "$subject_failed"
fi
echo "[INFO] backup of $src_dirs completed at: `date +%r`" >> $log_file

# unmount onedrive
unmount_onedrive

# mail and exit
echo "[INFO] End timestamp: `date`" >> $log_file
echo "[INFO] OneDrive backup complete." >> $log_file
mail_and_exit "$subject_success"
