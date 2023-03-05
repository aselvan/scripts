#!/bin/bash
#  
# audio2video.sh --- stupid simple wrapper to convert audion to video w/ static image
#
# NOTE: need ffmpeg binary in the path
#
# Author : Arul Selvan
# Version: Man 4, 2023

my_name=`basename $0`
os_name=`uname -s`
options="p:i:h?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

source_path=""
cover_image=""
dest_path=""

usage() {
  echo ""
  echo "Usage: $my_name -p <path> -i <coverimage>"
  echo "  -p <path> file/path for single file (or quoted for wildcard) convert audio to video"
  echo "  -i <cover.png> cover/static png image to use for all video files"
  echo ""
  echo "example: $my_name -i cover.png -p \"$HOME/*.m4a\""
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
    i)
      cover_image="$OPTARG"
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

if [ -z "$source_path" ] ; then
  usage
fi

if [ -z "$cover_image" ] ; then
  usage
fi

echo "[INFO] $my_name starting ..." > $log_file

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
    echo "[WARN] $fname is a directory, skipping ..." | tee -a $log_file
    continue
  fi
  base_part=${fname##*/}
  name_part=${base_part%.*}

  echo "converting $fname to ${name_part}.mp4 ..."
  ffmpeg -i $fname -i $cover_image -filter_complex "loop=-1:1:0" -shortest videos/${name_part}.mp4

done
