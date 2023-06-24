#!/bin/bash
#
# copy_metadata.sh --- copy metadata from source file to one or more destination files
#
# While all digital cameras add timestamp/gps metadata tags, often times we endup with 
# scanned images or old image files etc that don't have this information which you 
# may want to add or modify so tools (google photos, onedrive photos, apple photo etc) 
# that depend on creation time metadata to catalog media files. 
#
# This script will copy the metadata (for now just date, GPS only) from a source 
# reference file provided to a destination file/path.
#
#
# pre-req: exiftool
# install: 
#  brew install exiftool [MacOS]
#  apt-get install libimage-exiftool-perl [Linux]
#
# Author : Arul Selvan
# Version: Jun 24, 2023 

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.06.24
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="r:p:ovh?"
verbose=0
exiftool_opt="-m"
type_check=0
ref_file=""
dest_path=""
file_list=""
skip_tag="-wm cg"

usage() {
  cat << EOF

  Usage: $my_name [options]
    -r <name> ---> the reference source file to copy metadata from
    -p <path> ---> destination file/path to transfer copied metadata
    -o        ---> overwrite tags even if they exist [default: script will not change if tags present]
    -v        ---> verbose mode prints info messages, otherwise just errors are printed
    -h        ---> print usage/help

  example: $my_name -r source.jpg -p "*.jpg" -o

EOF
  exit 0
}

# check if file is a media file that could support metadata
is_media() {
  local f=$1
  local mtype=`file -b --mime-type $f | cut -d '/' -f 2`

  case $mtype in 
    jpg|jpeg|JPEG|JPG|PDF|pdf|mpeg|MPEG|MP3|mp3|mp4|MP4|png|PNG|mov|MOV|gif|GIF|TIFF|tiff)
      return 0
      ;;
    *)
      return 1 
      ;;
  esac
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
  write_log "[STAT]" "Running from: $my_path"
  write_log "[STAT]" "Start time:   `date +'%m/%d/%y %r'` ..."
}

# ----------  main --------------
# parse commandline options
init_log

while getopts $options opt; do
  case $opt in
    r)
      ref_file="$OPTARG"
      ;;
    p)
      dest_path="$OPTARG"
      ;;
    o)
      skip_tag=""
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done


if [ -z "$ref_file" ] ; then
  write_log "[ERROR]" "required argument i.e. reference file is missing!"
  usage
fi
if [ -z "$dest_path" ] ; then
  write_log "[ERROR]" "required argument i.e. destination path/file is missing!"
  usage
fi


# check if source path is a single file
if [ -f "$dest_path" ] ; then
  file_list="$dest_path"
else
  dir_name=$(dirname "$dest_path")
  file_name=$(basename "$dest_path")
  file_list=`ls -1 $dir_name/$file_name`
fi

for fname in ${file_list} ;  do
  is_media $fname
  if [ $? -ne 0 ] ; then
    write_log "[WARN]" "the file '$fname' is not known media type, skipping ..."
    continue
  fi
  write_log "[INFO]" "transfering date/gps info to '$fname' ..."
  exiftool $exiftool_opt -TagsFromFile $ref_file -AllDates -gps:all $skip_tag -overwrite_original $fname 2>&1 >> $log_file
done
