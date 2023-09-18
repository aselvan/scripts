#!/usr/bin/env bash
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
version=23.09.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)
options="r:p:ovh?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
verbose=0
green=32
red=31
blue=34
exiftool_opt="-m"
type_check=0
ref_file=""
dest_path=""
file_list=""
skip_tag="-wm cg"

usage() {
  cat << EOF

  $my_name --- copy metadata from source file to one or more destination files

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

reset_os_timestamp() {
  local fname=$1

  # reset file OS timestamp to match create date
  log.info "resetting OS timestamp to match create date of '$fname' ..."
  create_date=`exiftool -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`
  if [ -z "$create_date" ] ; then
    log.warn "metadata for $fname does not contain create date, skipping ..."
    return
  fi
 
  # validate createdate since sometimes images contain create date but show " 0000"
  if [ "$create_date" = " 0000" ] ; then
    log.warn "Invalid create date ($create_date) for $fname, skipping ..."
    return
  fi

  log.debug "resetting date: touch -t $create_date $fname"
  touch -t $create_date $fname
}

 
# ----------  main --------------
# parse commandline options
log.init

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
  log.error "Required argument i.e. reference file is missing!"
  usage
fi
if [ -z "$dest_path" ] ; then
  log.error "Required argument i.e. destination path/file is missing!"
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
    log.warn "The file '$fname' is not known media type, skipping ..."
    continue
  fi
  log.stat "Transfering date/gps and reseting OS timestamp of '$fname' ..." $green
  exiftool $exiftool_opt -TagsFromFile $ref_file -AllDates -gps:all $skip_tag -overwrite_original $fname 2>&1 >> $log_file
  reset_os_timestamp $fname
done
