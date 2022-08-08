#!/bin/bash
  
# reset_file_timestamp.sh --- reset a file's timestamp matching the 'createdate' from its metadata
#
# This script will read the file metadata from media files like jpeg,mp3 etc using exiftool and
# reset the OS filename timestamp to match the createdate in the metadata.
#
# Author : Arul Selvan
# Version: Jul 10, 2022

my_name=`basename $0`
os_name=`uname -s`
options="p:h?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
source_path="$HOME/*.jpg"
exiftool_bin="/usr/bin/exiftool"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -p <name> ---> file/path for single file (or quoted for wildcard) to reset [Default: \"$source_path\"]"
  echo ""
  echo "example: $my_name -f \"$source_path\""
  echo ""
  exit 0
}

# ----------  main --------------
# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      source_path="$OPTARG"
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

if [ -f $log_file ] ; then
  rm $log_file
fi
echo "[INFO] $my_name starting ..." > $log_file

if [ $os_name = "Darwin" ]; then
  exiftool_bin=/usr/local/bin/exiftool
fi

# ensure exiftool is available
if [ ! -e $exiftool_bin ] ; then
  echo "[ERROR] $exiftool_bin is required for this script to work"
  exit 1
fi

file_list=`ls -1 $source_path`

for fname in ${file_list} ;  do
  create_date=`$exiftool_bin -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`
  if [ -z $create_date ] ; then
    echo "[WARN] metadata for $fname does not contain create date, skipping ..." | tee -a $log_file
    continue
  fi

  echo "[INFO] resetting date: touch -t $create_date $fname" | tee -a $log_file
  touch -t $create_date $fname
done