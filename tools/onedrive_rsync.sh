#!/usr/bin/env bash
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
# Version history: 
#   Aug 21, 2022 --- Original version
#   Jan 11, 2024 --- refactor to use logger and function includes

# version format YY.MM.DD
version=24.01.11
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="OneDrive rsync script for backup"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="e:l:p:s:m:h"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"


# rsync/rclone options
# note: -a option contains -l and -D so we use no-XXX to remove them as we don't need them
rsync_opts="-azqt -O --no-links --no-D --delete --inplace --cvs-exclude --exclude=*.html --exclude=*.htm --exclude=*.backup --exclude=*.m3u --exclude=*.sh --exclude=thumb --exclude=jdothumb --exclude=*.exe --exclude=*.EXE --delete-excluded"
rclone_opt="--vfs-cache-mode writes --vfs-cache-max-age 5m --vfs-cache-max-size 64M"

# backup locations
photos_src="/var/www/photos"
videos_src="/var/www/video"
scrapbooks_src="/var/www/scrapbooks"
yt_videos="/data/videos4youtube"
debbie_backup="/data/debbie-backup"
src_dirs="$photos_src $videos_src $scrapbooks_src $yt_videos $debbie_backup"

onedrive_label="onedrive"
mount_point="/mnt/onedrive"
onedrive_root_path="/personal/home/media"
onedrive_mounted=0
onedrive_mount_wait=30

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <source> ---> one or more source directories to backup [default: \"$src_dirs\"]"
  -p <path>   ---> onedrive root path starting from label [$onedrive_label] to mount [default: $onedrive_root_path]"
  -l <label>  ---> onedrive label from rclone.conf [default: $onedrive_label]"
  -m <mount>  ---> local mount point to mount onedrive [default: $mount_point]"
  -e <email>  ---> email address to send success/failure messages
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -h -v
  
EOF
  exit 0
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
    log.stat "OneDrive is not mounted, attempting to mount..."

    rclone $rclone_opt mount $onedrive_label:$onedrive_root_path $mount_point --daemon
    rc=$?
    if [ $rc -ne 0 ]; then
      log.error "Error mounting OneDrive, exiting, error = $rc"
      exit 1
    fi

    # wait few sec to check the drive mount again
    log.stat "Waiting for $onedrive_mount_wait sec for OneDrive to mount..."
    /bin/sync
    sleep $onedrive_mount_wait 

    is_mounted
    if [ $? -ne 0 ]; then
      log.error "Error unable to mount OneDrive... giving up!"
      exit
    fi
    onedrive_mounted=1
  fi
  log.stat "OneDrive is mounted and ready..."
}

unmount_onedrive() {
  log.stat "Leaving ondrive mounted since buffered data is not making to remote storage (need more research).." 
  return

  log.stat "Unmounting OneDrive..."
  # just do a couple of syncs to flush buffers
  sync
  # unmount only if we mounted it in the first place
  if [ $onedrive_mounted -eq 0 ]; then
    log.warn "OneDrive was already mounted when we started, so leaving it mounted"
    return
  fi

  fusermount -zu $mount_point
  rc=$?
  if [ $rc -eq 0 ]; then
    log.stat "Onedrive unmount success"
  else
    log.error "Error unmounting onedrive, error = $rc"
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
    ?|h|*)
      usage
      ;;
   esac
done

# check for onedrive availability
check_onedrive

# start rsync
log.stat "Backup Sources: '$src_dirs'" 
rsync $rsync_opts $src_dirs ${mount_point}/. >>$my_logfile 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  log.error "Error while rsync; error = $rc ... terminating."
  unmount_onedrive
  send_mail "1"
  exit 1
fi

# unmount onedrive
unmount_onedrive

# mail and exit
log.stat "OneDrive backup complete."
log.stat "Total runtime: $(elapsed_time)"
send_mail "0"
