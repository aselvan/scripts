#!/bin/bash
#
# simple_rsync.sh --- simple copy using rsync with multiple sources
#
#
# Author:  Arul Selvan
# Version: Apr 18, 2023
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.04.21
my_name=`basename $0`
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
options="s:d:vh"

run_host=`hostname`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
rsync_opts="-rlptoq --ignore-errors --delete --cvs-exclude --temp-dir=/tmp --exclude \"*.vmdk\" --exclude=/root/gdrive"
IFS_old=$IFS
verbose=0

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

write_log() {
  local msg_type=$1
  local msg=$2

  # log info type only when verbose flag is set
  if [ "$msg_type" == "[INFO]" ] && [ $verbose -eq 0 ] ; then
    return
  fi

  echo "$msg_type $msg" | tee -a $log_file
}
init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "[STAT]" "$my_version"
  write_log "[STAT]" "starting at `date +'%m/%d/%y %r'` ..."
}

# ----------  main --------------
init_log

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
  write_log "[ERROR]" "Source and/or dest path missing! See usage"
  usage
fi

# start backup
write_log "[STAT]" "Starting rsync backup (target=$backup_dir) ..."

IFS=',' read -ra src_list_array <<< "$src_list"
for src_path in "${src_list_array[@]}"; do
  write_log "[INFO]" "    Backup Path: $src_path  ..."
  write_log "[INFO]" "    Start: `date +'%D %H:%M %p'`"
  nice -19 rsync $rsync_opts $src_path $backup_dir
  write_log "[INFO]" "    End:   `date +'%D %H:%M %p'`"

done

write_log "[STAT]" "Doing a OS sync ..."
sync
write_log "[STAT]" "Backup complete."
