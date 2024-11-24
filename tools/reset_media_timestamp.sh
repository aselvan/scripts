#!/usr/bin/env bash
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
#
# See Also: reset_file_timestamp.sh copy_metadata.sh exif_check.sh geocode_media_files.sh add_metadata.sh reset_media_timestamp.sh exif_check.sh
#
# Version History
# --------------
#   22.09.14 --- Initial version
#   24.04.07 --- Added see also

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=24.04.07
my_version="`basename $0` v$version"
my_title="reset a file timestamp using the 'createdate' from its metadata"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:t:h"
source_path=""
exiftool_opt="-m"
timestamp=`date +%Y%m%d%H%M`
type_check=0

usage() {
cat << EOF

$my_name - $my_title

Usage: $my_name [options]
  -p <path>      ---> file/path for single file (or quoted for wildcarda)
  -t <timestamp> ---> timestamp YYYYMMDDHHMM. If not provided, defaults to 'now' [$timestamp]
  -v             ---> enable verbose, otherwise just errors are printed

  example: $my_name -p image.jpg -t 202209141800
  example: $my_name -p "/home/images/*.jpg" -t 202209141800

  See Also: reset_file_timestamp.sh copy_metadata.sh exif_check.sh geocode_media_files.sh add_metadata.sh reset_media_timestamp.sh exif_check.sh

EOF
  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

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

# ensure exiftool is available
which exiftool >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  log.error "exiftool is required for this script to work, install it first [ex: brew install exiftool]."
  exit 1
fi

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
    log.warn "the file '$fname' is not known media type, skipping ..." | tee -a $my_logfile
    continue
  fi
  log.stat "change/add metadata & OS timestamp ($timestamp) to '$fname' ..." | tee -a $my_logfile
  exiftool $exiftool_opt -d "%Y%m%d%H%M" -AllDates="$timestamp" -overwrite_original $fname 2>&1 >> $my_logfile
  touch -t $timestamp $fname
done
