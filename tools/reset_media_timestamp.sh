#!/bin/bash
#
# reset_media_timestamp.sh --- add/change timestamp metadata on media files.
#
# While all digital cameras add timestamp metadata tags, often times we endup with 
# scanned images or old image files etc that don't have this information which you 
# may want to add or modify so tools (google photos, onedrive photos, apple photo etc) 
# that depend on creation time metadata to catalog media files. This script not only 
# will add/change timestamp metadata inside the image but will also change the
# OS/filesystem timestamp as well to mactch.
#
# pre-req: exiftool
# install: 
#  brew install exiftool [MacOS]
#  apt-get install libimage-exiftool-perl [Linux]
#
# Author : Arul Selvan
# Version: Sep 14, 2022

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=22.09.14
my_name=`basename $0`
my_version="$my_name v$version"
os_name=`uname -s`
options="p:t:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
source_path=""
exiftool_bin="/usr/bin/exiftool"
timestamp=`date +%Y%m%d%H%M`
type_check=0

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -p <name>       ---> file/path for single file (or quoted for wildcard)"
  echo "  -t <timestamp>  ---> timestamp YYYYMMDDHHMM. If not provided, defaults to 'now' [$timestamp]"
  echo ""
  echo "example: $my_name -p image.jpg -t 202209141800"
  echo "example: $my_name -p \"/home/images/*.jpg\" -t 202209141800"
  echo ""
  exit 0
}

# check if file is a media file that could support metadata
is_media() {
  local f=$1
  local mtype=`file -b --mime-type $f | cut -d '/' -f 2`

  case $mtype in 
    jpg|jpeg|JPEG|JPG|PDF|pdf|mpeg|MPEG|MP3|mp3|mp4|MP4|png|PNG)
      return 0
      ;;
    *)
      return 1 
      ;;
  esac
}

# ----------  main --------------
# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      source_path="$OPTARG"
      ;;
    t)
      timestamp="$OPTARG"
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
echo "[INFO] $my_version" | tee -a $log_file

if [ $os_name = "Darwin" ]; then
  exiftool_bin=/usr/local/bin/exiftool
fi

# ensure exiftool is available
if [ ! -e $exiftool_bin ] ; then
  echo "[ERROR] $exiftool_bin is required for this script to work"
  exit 1
fi

if [ -z "$source_path" ] ; then
  echo "[ERROR] required argument i.e. path/name is missing!"
  usage
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
  is_media $fname
  if [ $? -ne 0 ] ; then
    echo "[WARN] the file '$fname' is not known media type, skipping ..." | tee -a $log_file
    continue
  fi
  echo "[INFO] change/add metadata & OS timestamp ($timestamp) to '$fname' ..." | tee -a $log_file
  $exiftool_bin -d "%Y%m%d%H%M" -AllDates="$timestamp" -overwrite_original $fname 2>&1 >> $log_file
  touch -t $timestamp $fname
done
