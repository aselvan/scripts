#!/usr/bin/env bash
################################################################################
#  
# reset_file_timestamp.sh --- reset a file's timestamp using createtime in metadata
#
# This script will read the file metadata from media files like jpeg,mp3 etc 
# using exiftool and reset the OS filename timestamp to match the createdate in 
# the metadata.
#
# Author : Arul Selvan
# Created: Jul 10, 2022
#
#  See Also: 
#     reset_file_timestamp.sh copy_metadata.sh exif_check.sh geocode_media_files.sh 
#     add_metadata.sh reset_media_timestamp.sh exif_check.sh
#
################################################################################
# Version History
# --------------
#   22.07.10 --- Initial version
#   23.03.21 --- Use stanard logging, with terse support
#   24.03.31 --- Added "see also" for related tools
################################################################################

# version format YY.MM.DD
version=24.03.31
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Reset file timestamp using createdate from metadata"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:vh?"

source_path=""

usage() {
cat << EOF

$my_name - $my_title

Usage: $my_name [options]
  -p <path>  ---> file/path to reset timestamp using metadata's timestamp
  -v         ---> enable verbose, otherwise just errors are printed

example(s): 
  $my_name -p "$HOME/*.jpg"

See Also: 
  reset_file_timestamp.sh copy_metadata.sh exif_check.sh 
  geocode_media_files.sh add_metadata.sh reset_media_timestamp.sh exif_check.sh
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

# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      source_path="$OPTARG"
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
  usage
fi

# ensure exiftool is available
check_installed exiftool

# check if source path is a single file
if [ -f "$source_path" ] ; then
  file_list="$source_path"
  log.stat "Resetting timestamp using metadata for: $file_list"
else
  dir_name=$(dirname "$source_path")
  file_name=$(basename "$source_path")
  file_list=`ls -1 $dir_name/$file_name`
  log.stat "Resetting timestamp using metadata for: $dir_name/$file_name"
fi

for fname in ${file_list} ;  do
  # if filename is directory, skip
  if [ -d $fname ] ; then
    log.warn "$fname is a directory, skipping ..."
    continue
  fi

  create_date=`exiftool -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`
  if [ -z "$create_date" ] ; then
    log.warn "metadata for $fname does not contain create date, skipping ..."
    continue
  fi
 
  # validate createdate since sometimes images contain create date but show " 0000"
  if [ "$create_date" = " 0000" ] ; then
    log.warn "Invalid create date ($create_date) for $fname, skipping ..."
    continue
  fi

  log.debug "resetting date: touch -t $create_date $fname"
  touch -t $create_date $fname
done
