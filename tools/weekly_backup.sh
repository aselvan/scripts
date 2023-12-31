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

# version format YY.MM.DD
version=23.12.31
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Weekly back of selvans.net"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="e:o:h"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

title="selvans.net weekly backup"
run_host=`hostname`
desc="Weekly backup log file"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"
www_root=/var/www
std_header=${www_root}/std_header.html
std_footer=${www_root}/std_footer.html
html_file=${www_root}/weekly_backup_log.html

email_address=""
subject="trex backup results"
subject_failed="Weekly backup FAILED"
subject_space_low="Weekly backup LOWSPACE"
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
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -e <email>  ---> email address to send backup report
  -o <device> ---> mark this as offsite device for special handling [default: $offsite_device]
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -h -v
  
EOF
  exit 0
}

create_html_log() {
  cat $std_header| sed -e "$sed_st"  > $html_file
  echo "<body><pre>" >> $html_file
  cat $my_logfile  >> $html_file
  echo "</pre>" >> $html_file

  # write footer (takes care of ending body/html tags
  cat $std_footer >> $html_file
}

do_backup() {
  echo "Backup job start: `date`" >> $my_logfile
  echo "Checking backup device: $usb_mount" >> $my_logfile
  # mount the usb if it is not mounted already
  if [ ! -d $usb_mount/backup ];  then
    echo "    Backup device (${usb_mount}) is not mounted, attempting to mount ..." >> $my_logfile
    /bin/mount $usb_mount >> $my_logfile 2>&1
    status=$?
    if [ $status -eq 0 ]; then
       echo "    Device: '$usb_mount' is successfully mounted" >>  $my_logfile
    else
       echo "    Device: '$usb_mount' failed!, bailing out..." >> $my_logfile
       return 1
    fi
  fi
  # print device info and also check space left and mail if we are low
  df -h $usb_mount >> $my_logfile 2>&1
  free_space=`df -h $usb_mount|awk '$5 ~ /[0-9]/ {print $4}'`
  used_percent=`df -h $usb_mount|awk '$5 ~ /[0-9]/ {print $5}'|sed 's/%//g'`
  echo "Free space left in device: <b><font color=\"blue\">$free_space</font></b>" >> $my_logfile
  echo "" >> $my_logfile
  if [ $used_percent -gt $space_limit_percent ] ; then
      free_percent=`expr 100 - $used_percent`
      echo "<b><font color=\"red\">WARNING: low on space, only ${free_percent}% left on device</font></b>" >> $my_logfile
      if [ ! -z $email_address ] ; then
        echo "Backup will continue, and results will be mailed again. This mail is just for awareness" >> $my_logfile
        /bin/cat $my_logfile | /usr/bin/mail -s "$subject_space_low" $email_address
      fi
  fi

  # start backup
  echo "Starting rsync backup (target=$backup_dir) ..." >> $my_logfile
  echo "    Backup of /etc  ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /etc $backup_dir

  echo "    Backup of /root  ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /root $backup_dir

  echo "    Backup of /home  ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /home $backup_dir

  echo "    Backup of /var/www  ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /var/www $backup_dir

  echo "    Backup of /data/videos4youtube  ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /data/videos4youtube $backup_dir

  echo "    Backup of /data/debbie-backup  ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /data/debbie-backup $backup_dir

  # Skip this for offsite storage as we may have sensitive information
  # For off-site device copy just the encrypted container.
  if [ "$usb_mount" != "$offsite_device" ] ; then
    echo "    Backup of /data/transfer ... `date`" >> $my_logfile
    nice -19 $rsync_bin $rsync_opts /data/transfer $backup_dir
  else
    echo "    Off-site backup /data/transfer/arul-backup/data/encrypted" >> $my_logfile
    nice -19 $rsync_bin $rsync_opts /data/transfer/arul-backup/data/encrypted $backup_dir
  fi

  echo "    Backup of UFW config (/lib/ufw) ... `date`" >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /lib/ufw $backup_dir

  echo "    Backup of root's crontab ..." >> $my_logfile
	crontab -l > $backup_dir/${run_host}_root.crontab

  echo "Backup end: `date`" >> $my_logfile
  cp $my_logfile $backup_dir
  echo "Backup done, now synching ... `date`" >> $my_logfile

  # sync and umount. (umount probably does sync but just be sure)
  sync
  echo "Last step, unmounting ... `date`" >> $my_logfile
  /bin/umount $usb_mount
  echo "" >> $my_logfile
  return 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include functions, we dont need logger for this specific script as it has html code
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi

echo "selvans.net Weekly backup" > $my_logfile
echo "=========================" >> $my_logfile
echo "" >> $my_logfile
echo "Script: $my_version" >> $my_logfile
echo "Host:   $run_host" >> $my_logfile
echo "Date:   `date +'%b %d, %Y'`" >> $my_logfile

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
device_names=("Primary,/media/usb-1tb-2" "Secondary,/media/usb-1tb-3" "Tertiary eSATA-RAID,/media/sata-3tb" "Offsite SSD,$offsite_device" )

for devpair in "${device_names[@]}" ; do
  IFS=,
  keyval=($devpair)
  usb_desc=${keyval[0]}
  usb_mount=${keyval[1]}
  IFS=$IFS_old
  backup_dir=$usb_mount/backup
  echo "" >> $my_logfile
  echo ">>>>>>> $usb_desc backup target device/path: $backup_dir <<<<<<<<< " >> $my_logfile
  do_backup
  tb=$?
  if [ $tb -ne 0 ]; then
    echo "    ERROR: ${keyval[0]} backup failed!" >> $my_logfile
    backup_failed=1
  fi
done

# mail good if all backup devices are successful, otherwise even if one fails send bad mail
echo "" >> $my_logfile
if [ $backup_failed -eq 0 ] ; then
    echo "<b>Backup Result:</b> <b><font color=\"blue\">SUCCESS</font></b> on all devices" >> $my_logfile
    if [ ! -z $email_address ] ; then
      /bin/cat $my_logfile | /usr/bin/mail -s "$subject" $email_address
    fi
else
    echo "<b>Backup Result:</b> <b><font color=\"red\">FAILED</font></b> on one or more devices" >> $my_logfile
    if [ ! -z $email_address ] ; then    
      /bin/cat $my_logfile | /usr/bin/mail -s "$subject_failed" $email_address
    fi
fi
echo "<b>Total runtime:</b> $(elapsed_time)" >> $my_logfile

# write html log
create_html_log
