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
version=23.08.28
my_name=`basename $0`
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
options="s:d:vh"

run_host=`hostname`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
verbose=0
green=32
red=31
blue=34

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

# -- Log functions ---
log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}
log.stat() {
  log.init
  local msg=$1
  local color=$2
  if [ -z $color ] ; then
    color=$blue
  fi
  echo -e "\e[0;${color}m$msg\e[0m" | tee -a $log_file 
}
log.warn() {
  log.init
  local msg=$1
  echo -e "\e[0;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[0;31m$msg\e[0m" | tee -a $log_file 
}

# ----------  main --------------
log.init

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
log.stat "Starting rsync backup to Destination: $backup_dir"

IFS=',' read -ra src_list_array <<< "$src_list"
for src_path in "${src_list_array[@]}"; do
  log.stat "  Source:  $src_path  ..." $green
  log.stat "  Start:   `date +'%D %H:%M:%S %p'`" $green
  nice -19 rsync $rsync_opts $src_path $backup_dir
  if [ $? -ne 0 ] ; then
    log.error "  Backup failed, error code=$?"
  else
    log.stat "  End:    `date +'%D %H:%M:%S %p'`" $green
  fi
done

log.stat "Doing a OS sync ..."
sync
log.stat "Backup complete."
