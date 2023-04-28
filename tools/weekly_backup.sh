#!/bin/bash
#
# weekly_backup.sh --- script to do weekly back up of selvans.net 
#
# Note: this is hardcoded specifically for my server so probably needs to change
# quite a bit to use anywhere else but feel free to modify to fit your needs.
#
# Author:  Arul Selvan
# Version: May 25, 2013
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=13.05.25
my_name=`basename $0`
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
options_list="e:o:h"

title="selvans.net weekly backup"
run_host=`hostname`
desc="Weekly backup log file"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"
www_root=/var/www
std_header=$www_root/std_header.html
html_file=$www_root/weekly_backup_log.html

email_address=""
subject="trex backup results"
subject_failed="Weekly backup FAILED"
subject_space_low="Weekly backup LOWSPACE"
log_file=/data/backup/weekly_backup.log
usb_mount=/media/usb-portable
backup_dir=$usb_mount/backup
rsync_opts="-rlptgoq --ignore-errors --delete --cvs-exclude --temp-dir=/data/tmp --exclude \"*.vmdk\" --exclude=/root/gdrive"
rsync_bin="/usr/bin/rsync"
# when a device is 90% full, send a nag email
space_limit_percent=90
backup_failed=0
offsite_device="/media/usb-ssd-500g"
IFS_old=$IFS

# list of devices: descriptive name and mount points. NOTE: the /etc/fstab
# entry should be setup to right device for each of the mount point specified.
device_names=("Primary,/media/usb-1tb-2" "Secondary,/media/usb-1tb-3" "Tertiary eSATA-RAID,/media/sata-3tb" "Offsite SSD,$offsite_device" )

usage() {
  echo "Usage: $my_name [options]"
  echo "  -e <email_address> email address to send backup report"
  echo "  -o <offsite_device> mark offsite device for special handling [default: $offsite_device]"
  echo "  -h help"
  exit 0
}

create_html_log() {
  cat $std_header| sed -e "$sed_st"  > $html_file
  echo "<body><pre>" >> $html_file
  cat $log_file  >> $html_file
  echo "</pre></body></html>" >> $html_file
}

do_backup() {
  echo "Backup job start: `date`" >> $log_file
  echo "Checking backup device: $usb_mount" >> $log_file
  # mount the usb if it is not mounted already
  if [ ! -d $usb_mount/backup ];  then
    echo "    Backup device (${usb_mount}) is not mounted, attempting to mount ..." >> $log_file
    /bin/mount $usb_mount >> $log_file 2>&1
    status=$?
    if [ $status -eq 0 ]; then
       echo "    Device: '$usb_mount' is successfully mounted" >>  $log_file
    else
       echo "    Device: '$usb_mount' failed!, bailing out..." >> $log_file
       return 1
    fi
  fi
  # print device info and also check space left and mail if we are low
  df -h $usb_mount >> $log_file 2>&1
  free_space=`df -h $usb_mount|awk '$5 ~ /[0-9]/ {print $4}'`
  used_percent=`df -h $usb_mount|awk '$5 ~ /[0-9]/ {print $5}'|sed 's/%//g'`
  echo "Free space left in device: <b><font color=\"blue\">$free_space</font></b>" >> $log_file
  echo "" >> $log_file
  if [ $used_percent -gt $space_limit_percent ] ; then
      free_percent=`expr 100 - $used_percent`
      echo "<b><font color=\"red\">WARNING: low on space, only ${free_percent}% left on device</font></b>" >> $log_file
      if [ ! -z $email_address ] ; then
        echo "Backup will continue, and results will be mailed again. This mail is just for awareness" >> $log_file
        /bin/cat $log_file | /usr/bin/mail -s "$subject_space_low" $email_address
      fi
  fi

  # start backup
  echo "Starting rsync backup (target=$backup_dir) ..." >> $log_file
  echo "    Backup of /etc  ... `date`" >> $log_file
  nice -19 $rsync_bin $rsync_opts /etc $backup_dir

  echo "    Backup of /root  ... `date`" >> $log_file
  nice -19 $rsync_bin $rsync_opts /root $backup_dir

  echo "    Backup of /home  ... `date`" >> $log_file
  nice -19 $rsync_bin $rsync_opts /home $backup_dir

  echo "    Backup of /var/www  ... `date`" >> $log_file
  nice -19 $rsync_bin $rsync_opts /var/www $backup_dir

  echo "    Backup of /data/videos4youtube  ... `date`" >> $log_file
  nice -19 $rsync_bin $rsync_opts /data/videos4youtube $backup_dir

  # Skip this for offsite storage as we may have sensitive information
  # For off-site device copy just the encrypted container.
  if [ "$usb_mount" != "$offsite_device" ] ; then
    echo "    Backup of /data/transfer ... `date`" >> $log_file
    nice -19 $rsync_bin $rsync_opts /data/transfer $backup_dir
  else
    echo "    Off-site backup /data/transfer/arul-backup/data/encrypted" >> $log_file
    nice -19 $rsync_bin $rsync_opts /data/transfer/arul-backup/data/encrypted $backup_dir
  fi

  echo "    Backup of UFW config (/lib/ufw) ... `date`" >> $log_file
  nice -19 $rsync_bin $rsync_opts /lib/ufw $backup_dir

  echo "    Backup of root's crontab ..." >> $log_file
	crontab -l > $backup_dir/${run_host}_root.crontab

  echo "Backup end: `date`" >> $log_file
  cp $log_file $backup_dir
  echo "Backup done, now synching ... `date`" >> $log_file

  # sync and umount. (umount probably does sync but just be sure)
  sync
  echo "Last step, unmounting ... `date`" >> $log_file
  /bin/umount $usb_mount
  echo "" >> $log_file
  return 0
}

# --- Main ---
echo "selvans.net Weekly backup" > $log_file
echo "=========================" >> $log_file
echo "Script: $my_version" >> $log_file
echo "Host: $run_host" >> $log_file
echo "Date: `date +'%b %d, %Y'`" >> $log_file

# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    e)
      email_address=$OPTARG
      ;;
    o)
      offsite_device="$OPTARG"
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

# reset the list in case offsite_device is provided as cmdline option
device_names=("Primary,/media/usb-1tb-2" "Secondary,/media/usb-1tb-3" "Tertiary eSATA-RAID,/media/sata-3tb" "General Purpose,/media/usb-ssd-256g" "Offsite SSD,$offsite_device" )

for devpair in "${device_names[@]}" ; do
  IFS=,
  keyval=($devpair)
  usb_desc=${keyval[0]}
  usb_mount=${keyval[1]}
  IFS=$IFS_old
  backup_dir=$usb_mount/backup
  echo "" >> $log_file
  echo ">>>>>>> $usb_desc backup target device/path: $backup_dir <<<<<<<<< " >> $log_file
  do_backup
  tb=$?
  if [ $tb -ne 0 ]; then
    echo "    ERROR: ${keyval[0]} backup failed!" >> $log_file
    backup_failed=1
  fi
done

# mail good if all backup devices are successful, otherwise even if one fails send bad mail
echo "" >> $log_file
if [ $backup_failed -eq 0 ] ; then
    echo "Backup Result: <b><font color=\"blue\">SUCCESS</font></b> on all devices" >> $log_file
    if [ ! -z $email_address ] ; then
      /bin/cat $log_file | /usr/bin/mail -s "$subject" $email_address
    fi
else
    echo "Backup Result: <b><font color=\"red\">FAILED</font></b> on one or more devices" >> $log_file
    if [ ! -z $email_address ] ; then    
      /bin/cat $log_file | /usr/bin/mail -s "$subject_failed" $email_address
    fi
fi

# write html log
create_html_log
