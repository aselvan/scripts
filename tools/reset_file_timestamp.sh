#!/bin/bash
#  
# reset_file_timestamp.sh --- reset a file's timestamp matching the 'createdate' from its metadata
#
# This script will read the file metadata from media files like jpeg,mp3 etc using exiftool and
# reset the OS filename timestamp to match the createdate in the metadata.
#
# Author : Arul Selvan
# Created: Jul 10, 2022
#
# Version History
# --------------
#   22.07.10 --- Initial version
#   23.03.21 --- Use stanard logging, with terse support

# version format YY.MM.DD
version=23.03.21
my_name=`basename $0`
my_version="`basename $0` v$version"
os_name=`uname -s`
options="p:vh?"
verbose=0
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
source_path=""

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]"
    -p <path>   ---> file/path for single file (or quoted for wildcard) to reset using metadata's timestamp"
    -v <number> ---> Verbose=1 or terse=0 [Default: $verbose]
  
  example: $my_name -p \"$HOME/*.jpg\""
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
    p)
      source_path="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$source_path" ] ; then
  usage
fi

# ensure exiftool is available
which exiftool >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "ffmpeg is required for this script to work, install it first [ex: brew install ffmpeg]."
  exit 1
fi

# check if source path is a single file
if [ -f "$source_path" ] ; then
  file_list="$source_path"
else
  dir_name=$(dirname "$source_path")
  file_name=$(basename "$source_path")
  file_list=`ls -1 $dir_name/$file_name`
fi

for fname in ${file_list} ;  do
  # if filename is directory, skip
  if [ -d $fname ] ; then
    write_log "[WARN]" "$fname is a directory, skipping ..."
    continue
  fi

  create_date=`exiftool -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`
  if [ -z "$create_date" ] ; then
    write_log "[WARN]" "metadata for $fname does not contain create date, skipping ..."
    continue
  fi
 
  # validate createdate since sometimes images contain create date but show " 0000"
  if [ "$create_date" = " 0000" ] ; then
    write_log "[WARN]" "Invalid create date ($create_date) for $fname, skipping ..."
    continue
  fi

  write_log "[INFO]" "resetting date: touch -t $create_date $fname"
  touch -t $create_date $fname
done
