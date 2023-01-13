#!/bin/bash
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
version=23.01.13
my_name=`basename $0`
my_version="$my_name v$version"
os_name=`uname -s`
options="p:ltah"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
source_path=""
exiftool_bin="/usr/bin/exiftool"
exiftool_opt="-m"
check_gps=0
check_createtime=0

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -l  ---> check if lat/lon present as metadata"
  echo "  -t  ---> check if createdate present as metadata"
  echo "  -a  ---> check both createdate and gps present as metadata"
  echo ""
  echo "example: $my_name -l -p image.jpg"
  echo ""
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

has_gps() {
  local f=$1
  $exiftool_bin $exiftool_opt -if 'defined $gpslatitude' -filename -T $f 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then
    gps_present="Yes"
  else
    gps_present="No"
  fi
}

has_createtime() {
  local f=$1
  $exiftool_bin $exiftool_opt -if 'defined $createdate' -filename -T $f 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then
    createtime_present="Yes"
  else
    createtime_present="No"
  fi
}

# ----------  main --------------
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
    a)
      check_gps=1
      check_createtime=1
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
  output="File Name:$fname"
  if [ $check_gps -eq 1 ] ; then
    has_gps $fname
    output="$output ; GPS:$gps_present"
  fi
  if [ $check_createtime -eq 1 ] ; then
    has_createtime $fname
    output="$output ; Create Time:$createtime_present"
  fi
  echo "[INFO] $output"
done
