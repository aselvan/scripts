#!/bin/bash
#
# reset_directory_timestamp.sh --- reset directory timestamp to match the latest file in that diretory
#
# Author : Arul Selvan
# Version: Apr 7, 2019
# Version: Jul 15, 2022 (updated to use latest file as the ref timestamp)
#

my_name=`basename $0`
os_name=`uname -s`
options="p:h?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
directory_path="$HOME/test/travel"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -p <path> ---> directory path to start from [Default: \"$directory_path\"]"
  echo ""
  echo "example: $my_name -p \"$directory_path\""
  echo ""
  exit 0
}

# ----------  main --------------
# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      directory_path="$OPTARG"
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

if [ ! -d $directory_path ] ; then
  echo "[ERROR] $directory_path does not exists!, check and try again" | tee -a $log_file
  exit 1
fi

dir_list=`ls -1d ${directory_path}/*`

for dir in ${dir_list} ; do
  # get the latest file name in the dir
  recent_file=`ls -1t "$dir" |head -n1`
  if [ -z "$recent_file" ] ; then
    echo "[WARN] no file found in the directory $dir!, skip..."
    continue
  fi

  # reset the directory to the latest file found in the dir
  echo "[INFO] reset dir '$dir' timestamp to timestamp of '$recent_file' ..." | tee -a $log_file
  touch -r "$dir/$recent_file" "$dir"
done
