#!/usr/bin/env bash
#
###########################################################################################
# weekly_backup.sh --- script to do weekly back up of selvans.net 
#
# Note: this is hardcoded specifically for my server so probably needs to change
# quite a bit to use anywhere else but feel free to modify to fit your needs.
#
# Author:  Arul Selvan
# Version History:
#    May 25, 2013 --- Original version
#    Jan 14, 2024 --- Updated to use logger and function utilities
#    Jan 17, 2024 --- Updated to use rsync log, disabled special case handling for offsite
#    Mar 6,  2024 --- Added commandline option to provide device list array
#    Mar 11, 2024 --- Added second (new offsite SSD) to the list of default devices.
#    Aug 1,  2025 --- Added additional backup target i.e. for offsite purpose
###########################################################################################

# version format YY.MM.DD
version=25.08.01
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Weekly backup of selvans.net"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="e:d:o:vh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

title="selvans.net weekly backup"
desc="Weekly backup log file"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"
www_root=/var/www
std_header=${www_root}/std_header.html
std_footer=${www_root}/std_footer.html
html_file=${www_root}/weekly_backup_log.html
usb_mount=/media/usb-portable
backup_dir=$usb_mount/backup

# rsync options
rsync_log_file="/tmp/$(echo $my_name|cut -d. -f1)_rsync.log"
rsync_opts="-rlptgoq --ignore-errors --no-specials --no-devices --delete-after --cvs-exclude --log-file=$rsync_log_file --temp-dir=/data/tmp --exclude \"*.vmdk\" --exclude=/root/gdrive"
rsync_bin="/usr/bin/rsync"

# when a device is 90% full, send a nag email
space_limit_percent=90
backup_status=0
IFS_old=$IFS
current_device="N/A"
current_device_vendor="N/A"
current_device_model="N/A"

# list of devices: descriptive name and mount points. NOTE: the /etc/fstab
# entry should be setup to right device for each of the mount point specified. 
device_names=("PRIMARY (Seagate 1TB):/media/usb-1tb-2" "SECONDARY (WD Element 1TB):/media/usb-1tb-3" "TERTIARY (eSATA-RAID 3TB):/media/sata-3tb")
#optional_device="OFFSITE (Crucial/micron SSD 1TB):/media/usb-ssd-1tb-crucial"
#optional_device="OFFSITE (OFFSITE (HP 500g):/media/usb-ssd-500g"
optional_device=""
start_timestamp=`date`


usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -e <email>   ---> email address to send backup report
  -d <devices> ---> device name/value pair(s) [default: "${device_names[*]}"]
  -o <extra>   ---> additional name:device pair for offsite purpose 
  -v           ---> enable verbose, otherwise just errors are printed
  -h           ---> print usage/help

example(s): 
  $my_name -e foo@bar.com -d "DeviceName1:/mnt/backup,DeviceName2:/mnt/backup2"
  $my_name -e foo@bar.com -o "OFFSITE (Crucial/micron SSD 1TB):/media/usb-ssd-1tb-crucial"
  
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
  # for use in calculating elapsed time for each step in this
  local start_time=$SECONDS

  echo "Checking mount status for: $usb_mount" >> $my_logfile
  # mount the usb if it is not mounted already
  if [ ! -d $usb_mount/backup ];  then
    echo "    ${usb_mount} is not mounted, attempting to mount ..." >> $my_logfile
    /bin/mount $usb_mount >> $my_logfile 2>&1
    status=$?
    if [ $status -eq 0 ]; then
      echo "    Mountpoint:    $usb_mount is successfully mounted" >>  $my_logfile
      # now that it is mounted, get device, vendor, model etc
      current_device=`findmnt -o SOURCE -n ${usb_mount}`
      current_device_vendor=`udevadm info --query=property --name=$current_device | grep ID_VENDOR= | awk -F= '{print $2}'`
      current_device_model=`udevadm info  --query=property --name=$current_device | grep ID_MODEL=  | awk -F= '{print $2}'`
      echo "    Device ID:     $current_device" >> $my_logfile
      echo "    Device Vendor: $current_device_vendor" >> $my_logfile
      echo "    Device Model:  $current_device_model" >> $my_logfile
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
  if [ $used_percent -gt $space_limit_percent ] ; then
    free_percent=`expr 100 - $used_percent`
    echo "<b><font color=\"red\">WARNING: low on space, only ${free_percent}% left on device</font></b>" >> $my_logfile
    echo "Backup will continue, and results will be mailed again. This mail is just for awareness" >> $my_logfile
    send_mail "2"
  fi

  # start backup (time each step)
  start_time=$SECONDS
  echo "Starting rsync (target=$backup_dir) ..." >> $my_logfile
  echo -n "    Backup of /etc  ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /etc $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of /root  ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /root $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of /home  ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /home $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of /var/www  ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /var/www $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of /data/videos4youtube  ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /data/videos4youtube $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of /data/debbie-backup  ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /data/debbie-backup $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of /data/transfer ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /data/transfer $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of UFW config (/lib/ufw) ... " >> $my_logfile
  nice -19 $rsync_bin $rsync_opts /lib/ufw $backup_dir
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  start_time=$SECONDS
  echo -n "    Backup of root's crontab ..." >> $my_logfile
	crontab -l > $backup_dir/${host_name}_root.crontab
  echo "$(($SECONDS - $start_time)) second(s)." >> $my_logfile

  cp $my_logfile $backup_dir
  echo "Backup done, now synching ... " >> $my_logfile

  # sync and umount. (umount probably does sync but just be sure)
  sync
  echo "Last step, unmounting device ... " >> $my_logfile
  /bin/umount $usb_mount
  return 0
}

# calls do_backup for one device
backup_device() {
  #local devpair="$1"
  IFS=:
  keyval=($devpair)
  usb_desc=${keyval[0]}
  usb_mount=${keyval[1]}
  IFS=$IFS_old
  backup_dir=$usb_mount/backup
  echo "" >> $my_logfile
  echo ">>>>>>> $usb_desc backup target device/path: $backup_dir <<<<<<<<< " >> $my_logfile
  
  device_start_time=$SECONDS
  log.debug "Backing up to: $backup_dir"
  do_backup
  tb=$?
  if [ $tb -ne 0 ]; then
    echo "    ERROR: ${keyval[0]} backup failed!" >> $my_logfile
    backup_status=1
  fi
  echo "Total elapsed time: <b><font color=\"blue\">$(($SECONDS - $device_start_time))</font></b> seconds." >> $my_logfile
  echo "" >> $my_logfile
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi

# init logs
log.init 
echo "selvans.net --- Weekly backup log" > $my_logfile
echo "=================================" >> $my_logfile
echo "" >> $my_logfile
echo "Script: $my_version" >> $my_logfile
echo "Host:   $host_name" >> $my_logfile
echo "Date:   `date +'%b %d, %Y'`" >> $my_logfile

# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    e)
      email_address=$OPTARG
      ;;
    o)
      optional_device="$OPTARG"
      ;;
    d)
      IFS=',' read -r -a device_names <<< "${OPTARG}"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
   esac
done


# remove rsync logfile if present so it doesn't grow as rsync just appends
if [ -f $rsync_log_file ] ; then
  rm -f $rsync_log_file
fi

# loop through all backup devices.
for devpair in "${device_names[@]}" ; do
  log.debug "Main Devpair: $devpair"
  backup_device
done

# Do we have optional device provided via -o argument? 
if [ ! -z "$optional_device" ] ; then
  log.debug "Optional Devpair: $optional_device"
  devpair=$optional_device
  backup_device
fi

# mail good if all backup devices are successful, otherwise even if one fails send bad mail
echo "" >> $my_logfile
if [ $backup_status -eq 0 ] ; then
    echo "<b>Backup Result:</b> <b><font color=\"blue\">SUCCESS</font></b> on all devices" >> $my_logfile
else
    echo "<b>Backup Result:</b> <b><font color=\"red\">FAILED</font></b> on one or more devices" >> $my_logfile
fi
echo "<b>Start time:</b> $start_timestamp" >> $my_logfile
echo "<b>End time:  </b> `date`" >> $my_logfile
echo "<b>Total backup runtime:</b><font color=\"blue\">$(elapsed_time)</font>" >> $my_logfile

# mail the report 
send_mail "$backup_status" "$my_logfile"

# write html log
create_html_log
