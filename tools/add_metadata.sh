#!/usr/bin/env bash
################################################################################
#
# add_metadata.sh --- add exif metadata to one or more destination files
#
# This script will add the exif metadata (for now owner,copyright) 
# reference file provided to a destination file/path. Also resets 
# file timestamps.
#
#
# pre-req: exiftool
# install: 
#  brew install exiftool [MacOS]
#  apt-get install libimage-exiftool-perl [Linux]
#
# Author:  Arul Selvan
# Created: Jun 24, 2023
#
# See Also: reset_file_timestamp.sh copy_metadata.sh exif_check.sh 
#           geocode_media_files.sh add_metadata.sh reset_media_timestamp.sh 
#           exif_check.sh
#
################################################################################
# Version History
#
#   Sep 17, 2023 --- Initial version
#   Mar 31, 2024 --- Use standard includes for logging, added desc metadata.
#   Feb 5,  2025 --- Use use current date/time if missing from image file
#
################################################################################

# version format YY.MM.DD
version=25.02.05
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="add metadata (for now just owner,artist,copyright) to one or more destination files"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:c:a:o:d:vh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

exiftool_opt="-m"
type_check=0
ref_file=""
dest_path=""
file_list=""
skip_tag="-wm cg"

# defaukt metadata
artist="Arul Selvan"
owner="Arul Selvan"
copyright="Copyright (c) 2023-2025 SelvanSoft, LLC."
description="Media by SelvanSoft, LLC."

usage() {
  cat << EOF

  $my_name - $my_title

  Usage: $my_name [options]
    -p <path>      ---> destination file/path to add metadata
    -c <copyright> ---> copyright string [default: $copyright]
    -a <artist>    ---> artist name [default: $artist]
    -o <owner>     ---> owner name [default: $owner]
    -d <desc>      ---> description string to set [default: $description]
    -v             ---> verbose mode prints info messages, otherwise just errors are printed
    -h             ---> print usage/help

example: $my_name -p "*.jpg" -o "Foobar" -c "Copyright (c) 2025, Foobar, allrights reserved"

See Also: 
  reset_file_timestamp.sh copy_metadata.sh exif_check.sh geocode_media_files.sh 
  add_metadata.sh reset_media_timestamp.sh exif_check.sh

EOF
  exit 0
}


reset_os_timestamp() {
  local fname=$1

  # reset file OS timestamp to match create date
  log.info "resetting OS timestamp to match create date of '$fname' ..."
  create_date=`exiftool -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`
  if [ -z "$create_date" ] ; then
    log.warn "$fname does not contain create date, using current date ..."
    create_date=`date +"%Y%m%d%H%M.%S"`
    exiftool $exiftool_opt -d "%Y%m%d%H%M.%S" -AllDates="$create_date" -overwrite_original $fname 2>&1 >> $my_logfile
  fi

  # validate createdate since sometimes images contain create date but show " 0000"
  if [ "$create_date" = " 0000" ] ; then
    log.warn "Invalid create date ($create_date) for $fname, skipping ..."
    return
  fi

  log.debug "resetting date: touch -t $create_date $fname"
  touch -t $create_date $fname
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
      dest_path="$OPTARG"
      ;;
    c)
      copyright="$OPTARG"
      ;;
    a)
      artist="$OPTARG"
      ;;
    o)
      owner="$OPTARG"
      ;;
    d)
      description="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done


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
  log.stat "Adding owner/copyright info & reseting OS timestamp of '$fname' ..." $green
  exiftool $exiftool_opt -artist="$artist" -copyright="$copyright" -ownername="$owner" -ImageDescription="$description" -overwrite_original $fname 2>&1 >> $my_logfile
  reset_os_timestamp $fname
done
