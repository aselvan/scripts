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
#
# Version History:
#   Jan 13, 2023 --- Original version
#


# version format YY.MM.DD
version=24.04.25
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Query specific exif metadata present on a media file."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:ltah"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

source_path=""
exiftool_opt="-m"
check_gps=0
check_camera=0
check_createtime=0
dir_name=""

usage() {
  cat << EOF
$my_name --- $my_title

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

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile


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
  if [ ! -z "$dir_name" ] ; then
    fname="$dir_name/$file_name/$fname"
  fi

  is_media $fname
  if [ $? -ne 0 ] ; then
    log.warn "The file '$fname' is not known media type, skipping ..."
    continue
  fi
  output="File Name: `basename $fname`"
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
