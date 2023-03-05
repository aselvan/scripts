#!/bin/bash
#
# media_type.sh --- list file media type, optionally filter to show specific type
#
# Given a path, recursivly list filename and type of the entry is one of those "media" 
# types like jpg|jpeg|JPEG|JPG|PDF|pdf ... etc
#
# Author  : Arul Selvan
# Version : Mar 5, 2023 --- original version
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.03.05
my_name=`basename $0`
my_version="$my_name v$version"
os_name=`uname -s`
options="p:t:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
source_path=""
type_filter=""

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -p <name>    ---> path to start to recurse from"
  echo "  -t <type>    ---> filter by type i.e. mp4, mp4, m2a etc"
  echo ""
  echo "example: $my_name -p \"/home/music\" -t mp3"
  echo ""
  exit 0
}

# check if file is a media file that could support metadata
is_media() {
  local f=$1
  local mtype=`file -b --mime-type $f | cut -d '/' -f 2`

  case $mtype in 
    jpg|jpeg|JPEG|JPG|PDF|pdf|mpeg|MPEG|MP3|mp3|m4a|x-m4a|mp4|MP4|png|PNG|mov|MOV|gif|GIF|TIFF|tiff)
      # see if we need to filter
      if [ ! -z $type_filter ] ; then
        if [ $mtype = $type_filter ] ; then
          echo "File: $f ; type: $mtype"
        fi
      else
        echo "File: $f ; type: $mtype"
      fi
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
      type_filter="$OPTARG"
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

if [ -z "$source_path" ] ; then
  echo "[ERROR] required arguments missing i.e. path " | tee -a $log_file
  usage
fi

# just use find
find $source_path -type f  | while read file; do is_media $file; done
