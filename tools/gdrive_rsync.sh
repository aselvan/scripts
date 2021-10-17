#!/bin/bash
#
# gdrive_rsync.sh
#   Wrapper script to backup (i.e. copy www/photos, www/video to gdrive) using google-drive-ocamlfuse 
#   client that mounts the gdrive as a fuse filesystem under ~/gdrive [create the directory first]
#
# ref: https://github.com/astrada/google-drive-ocamlfuse
#
# Author:  Arul Selvan
# Version: May 17, 2015
#
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="e:h"

# rsync options
# note: -a option contains -l and -D so we use no-XXX to remove them as we don't need them
rsync_opts="-aq --no-links --no-D --delete --inplace --exclude={*.html,*.htm,*.backup,*.m3u,*.sh,thumb,jdothumb,*.exe,*.EXE} --delete-excluded"

# TODO: backup locations (change as needed)
photos_src="/var/www/photos"
videos_src="/var/www/video"
gdrive_dest="/root/gdrive/home/media"
subject_success="gDrive rsync success"
subject_failed="gDrive rsync failed"
email_address=
gdrive_mounted=0
gdrive_mount_wait=10

usage() {
  echo "Usage: $my_name [options]"
  echo "  -e <email_address> email address to send status [default: $email_address]"
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

check_gdrive() {
  # mount gdrive if not mounted already
  if [ ! -d $gdrive_dest ]; then
    echo "[INFO] gDrive is not mounted, attempting to mount..." >> $log_file
    /usr/bin/google-drive-ocamlfuse ~/gdrive
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "[ERROR] mounting gDrive, exiting, error = $rc" >> $log_file
      exit
    fi
 
    /bin/sync
    # wait few sec to check the drive mount again
    echo "[INFO] Waiting for $gdrive_mount_wait sec for gDrive to mount..." >> $log_file
    sleep $gdrive_mount_wait 
    # just do a ls 
    echo "[INFO] Ensuring we can ls the dir $gdrive_dest ..." >> $log_file
    ls -l $gdrive_dest >> $log_file 2>&1
    # just double check
    if [ ! -d $gdrive_dest ]; then
      echo "[ERROR] Unable to mount gDrive... giving up!" >> $log_file
      exit
    fi
    gdrive_mounted=1
  fi
  echo "[INFO] gDrive is mounted and ready..." >> $log_file
}

unmount_gdrive() {
  echo "[INFO] unmounting gDrive..." >> $log_file 
  
  # just do a couple of syncs to flush buffers
  /bin/sync
  /bin/sync

  # unmount only if we mounted it in the first place
  if [ $gdrive_mounted -eq 0 ]; then
    echo "[INFO] gDrive was already mounted when we started, so leaving it mounted" >> $log_file
    return
  fi
  /bin/fusermount -u ~/gdrive
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "[INFO] gdrive unmount success" >> $log_file
  else
    echo "[ERROR] unmounting gdrive, error = $rc" >> $log_file
  fi 
}

# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    e)
      email_address=$OPTARG
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

echo "[INFO] gDrive rsync" > $log_file
echo "[INFO] Start timestamp: `date`" >> $log_file

# check for gdrive availability
check_gdrive

# start rsync
echo "[INFO] Backup of $photos_src starting at: `date +%r`" >> $log_file
/usr/bin/rsync $rsync_opts $photos_src $gdrive_dest >>$log_file 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "[ERROR] while rsync; error = $rc ... terminating." >> $log_file
  unmount_gdrive
  mail_and_exit "$subject_failed"
fi
echo "[INFO] backup of $photos_src completed at: `date +%r`" >> $log_file

echo "[INFO] Backup of $videos_src starting at: `date +%r`" >> $log_file
/usr/bin/rsync $rsync_opts $videos_src $gdrive_dest >>$log_file 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "[ERROR] while rsync; error = $rc ... terminating." >> $log_file
  unmount_gdrive
  mail_and_exit "$subject_failed"
fi
echo "[INFO] backup of $videos_src completed at: `date +%r`" >> $log_file

# unmount gdrive
unmount_gdrive

# mail and exit
echo "[INFO] End timestamp: `date`" >> $log_file
echo "[INFO] gDrive backup complete." >> $log_file
mail_and_exit "$subject_success"
