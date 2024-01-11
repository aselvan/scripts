#!/usr/bin/env bash
#
# gdrive_rsync.sh
#   Wrapper script to backup (i.e. copy www/photos, www/video to gdrive) using google-drive-ocamlfuse 
#   client that mounts the gdrive as a fuse filesystem under ~/gdrive [create the directory first]
#
# ref: https://github.com/astrada/google-drive-ocamlfuse
#
# Author:  Arul Selvan
# Version History: 
#   May 17, 2015 - Original
#   Oct 22, 2022 - Removed video backup to conserve space since we have videos in onedirve which is 1TB size
#   Jan 10, 2024 - Use logger.sh and function.sh
#

# version format YY.MM.DD
version=24.01.10
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="gDrive rsync script for backup"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="e:hv"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# rsync options
# note: -a option contains -l and -D so we use no-XXX to remove them as we don't need them
rsync_opts="-aq --no-links --no-D --delete --inplace --exclude=*.html --exclude=*.htm --exclude=*.backup --exclude=*.m3u --exclude=*.sh --exclude=thumb --exclude=jdothumb --exclude=*.exe --exclude=*.EXE --delete-excluded"

# TODO: backup locations (change as needed)
photos_src="/var/www/photos"
videos_src="/var/www/video"
scrapbooks_src="/var/www/scrapbooks"
gdrive_dest="/root/gdrive/home/media"
gdrive_mounted=0
gdrive_mount_wait=10

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -e <email> ---> email address to send success/failure messages
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name -e foo@bar.com
  
EOF
  exit 0
}

check_gdrive() {
  # mount gdrive if not mounted already
  if [ ! -d $gdrive_dest ]; then
    log.stat "gDrive is not mounted, attempting to mount..."
    /usr/bin/google-drive-ocamlfuse ~/gdrive
    rc=$?
    if [ $rc -ne 0 ]; then
      log.error "Error mounting gDrive, exiting, error = $rc"
      exit
    fi
 
    /bin/sync
    # wait few sec to check the drive mount again
    log.stat "Waiting for $gdrive_mount_wait sec for gDrive to mount..."
    sleep $gdrive_mount_wait
    # just do a ls 
    log.stat "Ensuring we can ls the dir $gdrive_dest ..."
    ls -l $gdrive_dest >> $my_logfile 2>&1
    # just double check
    if [ ! -d $gdrive_dest ]; then
      log.error "Unable to mount gDrive... giving up!"
      exit
    fi
    gdrive_mounted=1
  fi
  log.stat "gDrive is mounted and ready..."
}

unmount_gdrive() {
  log.stat "Unmounting gDrive..."
  
  # just do a couple of syncs to flush buffers
  /bin/sync
  /bin/sync

  # unmount only if we mounted it in the first place
  if [ $gdrive_mounted -eq 0 ]; then
    log.stat "gDrive was already mounted when we started, so leaving it mounted"
    return
  fi
  /bin/fusermount -u ~/gdrive
  rc=$?
  if [ $rc -eq 0 ]; then
    log.stat "gDrive unmount success"
  else
    log.error "Unmounting gdrive, error = $rc" >> $my_logfile
  fi 
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

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    v)
      verbose=1
      ;;
    e)
      email_address="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
   esac
done

# check for gdrive availability
check_gdrive

# sync photos
log.stat "Backup of $photos_src starting at: `date +%r`"
/usr/bin/rsync $rsync_opts $photos_src $gdrive_dest >> $my_logfile 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  log.error "Error while rsync; error = $rc ... terminating." 
  unmount_gdrive
  send_mail "1"
  exit 1
fi
log.stat "Backup of $photos_src completed at: `date +%r`"

# sync scrapbooks
log.stat "Backup of $scrapbooks_src starting at: `date +%r`"
/usr/bin/rsync $rsync_opts $scrapbooks_src $gdrive_dest >>$my_logfile 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  log.error "Error while rsync; error = $rc ... terminating."
  unmount_gdrive
  send_mail "1"
  exit 2
fi
log.stat "Backup of $scrapbooks_src completed at: `date +%r`"

#########################################################################
# Removed video backup to conserve space since we have videos in onedirve 
# which is much larger i.e. 1TB. See onedrive_rsync.sh where videos are 
# backed up to onedrive storage.
#
# -Arul, Oct 22, 2022
####################################################################
# sync videos
#log.stat "Backup of $videos_src starting at: `date +%r`"
#/usr/bin/rsync $rsync_opts $videos_src $gdrive_dest >>$my_logfile 2>&1
#rc=$?
#if [ $rc -ne 0 ]; then
#  log.error "Error while rsync; error = $rc ... terminating." >> $my_logfile
#  unmount_gdrive
#  send_mail "1"
#fi
#echo "[INFO] backup of $videos_src completed at: `date +%r`" >> $my_logfile

# unmount gdrive
unmount_gdrive

# mail and exit
log.stat "gDrive backup complete."
log.stat "Total runtime: $(elapsed_time)"
send_mail "0"
