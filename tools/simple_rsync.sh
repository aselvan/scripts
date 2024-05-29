#!/usr/bin/env bash
#
# simple_rsync.sh --- simple copy using rsync with multiple sources to single destination
#
#
# Author:  Arul Selvan
# Version: Apr 18, 2023
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.11.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:d:vh"
run_host=`hostname`
rsync_opts="-rlptoq --ignore-errors --delete --cvs-exclude --temp-dir=/tmp --exclude \"*.vmdk\" --exclude=/root/gdrive"
IFS_old=$IFS

# source paths
src_list=""
backup_dir=""

usage() {
cat << EOF
Usage: $my_name [options]
  -s <source_dirs>     --> source directories separated by comma [$src_list]
  -d <destination_dir> --> destination directory to sync [$backup_dir]
  -v enable verbose mode
  -h help

example: $my_name -s "/path/dir, path/dir" -d /data/save
  
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

# parse commandline options
while getopts $options opt; do
  case $opt in
    s)
      src_list="$OPTARG"
      ;;
    d)
      backup_dir="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# check args
if [ -z "$src_list" ] || [ -z "$backup_dir" ] ; then
  log.error "Source and/or dest path missing! See usage"
  usage
fi

# start backup
log.stat "Destination: $backup_dir"

IFS=',' read -ra src_list_array <<< "$src_list"
for src_path in "${src_list_array[@]}"; do
  log.stat "  Source:  $src_path" $green
  log.stat "  Start:   `date +'%D %H:%M:%S %p'`" $green
  nice -19 rsync $rsync_opts $src_path $backup_dir
  if [ $? -ne 0 ] ; then
    log.error "  Backup failed, error code=$?"
  else
    log.stat "  Elapsed: $(elapsed_time)" $green
  fi
  echo ""
done

log.stat "Doing a OS sync ..."
sync
log.stat "Backup complete."
