#!/usr/bin/env bash
#
# exif_check.sh --- Query specific exif metadata present on a media file
#
# pre-req: exiftool
# install: 
#  brew install exiftool [MacOS]
#  apt-get install libimage-exiftool-perl [Linux]
#
# Author : Arul Selvan
# Version: Jan 13, 2023

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.09.17
my_name=`basename $0`
my_version="$my_name v$version"
os_name=`uname -s`
options="p:ltah"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
verbose=0
failure=0
green=32
red=31
blue=34
source_path=""
exiftool_opt="-m"
check_gps=0
check_camera=0
check_createtime=0

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  $my_name --- Query specific exif metadata present on a media file

  Usage: $my_name [options]
    -l  ---> check if lat/lon present as metadata
    -t  ---> check if createdate present as metadata
    -a  ---> check both createdate and gps present as metadata
    -v  ---> verbose mode prints info messages, otherwise just errors are printed
    -h  ---> print usage/help
  
  example: $my_name -l -p image.jpg
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

has_camera() {
  local f=$1
  # must be an easier way to tell exiftool to spit out tag value but this should work as well
  camera_model=$(exiftool $f | grep "Camera Model Name"|awk -F: '{print $2}')
  if [ -z "$camera_model" ] ; then
    camera_model="Unknown"
  fi
}

has_gps() {
  local f=$1
  exiftool $exiftool_opt -if 'defined $gpslatitude' -filename -T $f 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then
    gps_present="Yes"
  else
    gps_present="No"
  fi
}

has_createtime() {
  local f=$1
  exiftool $exiftool_opt -if 'defined $createdate' -filename -T $f 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then
    createtime_present="Yes"
  else
    createtime_present="No"
  fi
}

# ----------  main --------------
log.init

# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      source_path="$OPTARG"
      ;;
    l)
      check_gps=1
      ;;
    t)
      check_createtime=1
      ;;
    c)
      check_camera=1
      ;;
    a)
      check_gps=1
      check_createtime=1
      check_camera=1      
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$source_path" ] ; then
  log.error "Required argument i.e. path/name is missing!"
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
    log.warn "The file '$fname' is not known media type, skipping ..."
    continue
  fi
  output="File Name:$fname"
  if [ $check_gps -eq 1 ] ; then
    has_gps $fname
    output="$output ; GPS:$gps_present"
  fi
  if [ $check_createtime -eq 1 ] ; then
    has_createtime $fname
    output="$output ; Create Time:$createtime_present"
  fi
  if [ $check_camera -eq 1 ] ; then
    has_camera $fname
    output="$output ; Camera:$camera_model"
  fi

  log.stat "$output"
done
