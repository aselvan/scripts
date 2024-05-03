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
#   May 3,  2024 --- refactor to use rclone sync instead of mount & use OS rsync

# version format YY.MM.DD
version=24.05.03
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="OneDrive rsync script for backup using rclone."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="e:l:p:s:thv"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# rclone options
# note: --metadata is similar to -a i.e. copy file perm/time etc; -l copy links as link
rclone_opts_quite="-q"
rclone_opts_metadata="--metadata"
rclone_opts="-l --exclude=*.htm --exclude=*.docx --exclude=*.backup --exclude=*.sh --exclude=*.html --exclude=*.htm --exclude=jdothumb/ --exclude=thumb/ --exclude=*.backup --exclude=*.m3u --exclude=*.sh"
failure=0

# backup locations
photos_src="/var/www/photos"
videos_src="/var/www/video"
scrapbooks_src="/var/www/scrapbooks"
yt_videos="/data/videos4youtube"
debbie_backup="/data/debbie-backup"
src_dirs="$photos_src $videos_src $scrapbooks_src $yt_videos $debbie_backup"

onedrive_label="onedrive"
onedrive_root_path="/personal/home/media"

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -s <source> ---> one or more source directories to backup [default: "$src_dirs"].
  -p <path>   ---> onedrive root path starting from label [$onedrive_label] to mount [default: $onedrive_root_path].
  -l <label>  ---> onedrive label from rclone.conf [default: $onedrive_label].
  -e <email>  ---> email address to send success/failure messages.
  -v          ---> enable verbose, otherwise just errors are printed.
  -t          ---> test run just to see what would be done.
  -h          ---> print usage/help.

example: $my_name -s "/home/photos /home/videos" -e foo@bar.com
  
EOF
  exit 0
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
    t)
      rclone_opts_quite="--dry-run"
      ;;
    s)
      src_dirs=$OPTARG
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
   esac
done

# rclone in MacOS does not support metadata flag!
if [ "$os_name" = "Darwin" ] ; then
  rclone_opts_metadata=""
fi

# start sync
log.stat "Source dirs: '$src_dirs'"
for src in $src_dirs ; do 
  dir=`basename $src`
  log.stat "Backing up: $src ..."
  rclone sync $rclone_opts_quite $rclone_opts_metadata $rclone_opts $src ${onedrive_label}:${onedrive_root_path}/${dir} >> $my_logfile 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    log.error "Error while rclone sync; error = $rc, continuing w/ next source"
    failure=1
  fi
done

# mail and exit
log.stat "OneDrive backup complete."
log.stat "Total runtime: $(elapsed_time)"
send_mail "$failure"
