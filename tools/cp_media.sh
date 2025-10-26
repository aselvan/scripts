#!/usr/bin/env bash
################################################################################
# cp_media.sh --- Copy media files based on createdate metadata
#
# Copies media files (jpg,gif,mp4... etc) with create date matching user specified 
# timestamp window. Optionally, you can copy based on OS timestamp instead with 
# -o option
#
# Pre Req: exiftool
#
# Author:  Arul Selvan
# Created: Oct 24, 2025
################################################################################
# Version History:
#   Oct 24, 2025 --- Original version
################################################################################

# version format YY.MM.DD
version=25.10.24
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Copy media files based on createdate metadata"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:d:f:t:ovh?"

s_path=""
d_path="."
ts_from=""
ts_to=`date +"%Y:%m:%d %H:%M"`
os_timestamp=0

usage() {
  cat << EOF
  
$my_name --- $my_title
Usage: $my_name [options]
  -s <path>      ---> Source path where image files are
  -d <path>      ---> Destination path [default: $d_path]
  -f <timestamp> ---> from timestamp [format: YYYY:MM:DD HH:MM]
  -t <timestamp> ---> to timestamp [default: $ts_to]
  -o             ---> Use OS file timestamp to compare [default: 'CreateDate' metadata will be used]
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

example(s): 
  $my_name -s ~/photos -d /tmp -f "2025:01:01 00:00" -t "2025:06:30 11:59"
  
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
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

check_installed exiftool

# parse commandline options
while getopts $options opt ; do
  case $opt in
    s)
      s_path="$OPTARG"
      ;;
    d)
      d_path="$OPTARG"
      ;;
    f)
      ts_from="$OPTARG"
      ;;
    t)
      ts_to="$OPTARG"
      ;;
    o)
      os_timestamp=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check required args
if [ -z "$s_path" ] ; then
  log.error "required argument missing [-s <path] ... see usage"
  usage
fi

if [ -z "$ts_from" ] ; then
  log.error "required argument missing [-f <timestamp>]... see usage"
  usage
fi

if [ $os_timestamp -eq 1 ] ; then
  log.stat "Using OS file timestamp ..."
  # format the timestamp to what find command expects
  ts_from="$(echo "$ts_from" | sed 's/^\([0-9]*\):\([0-9]*\):\([0-9]*\)/\1-\2-\3/')"
  ts_to="$(echo "$ts_to" | sed 's/^\([0-9]*\):\([0-9]*\):\([0-9]*\)/\1-\2-\3/')"
  find $s_path -type f -newermt "$ts_from" ! -newermt "$ts_to" -exec cp -p {} ~/Desktop/test \;
else 
  log.stat "Using metadata timestamp ..."
  time_window="\$CreateDate ge \"$ts_from\" and \$CreateDate le \"$ts_to\""
  exiftool -if "$time_window" -r -o $d_path $s_path
  # exiftool resets file timestamp to current time, so reset it to media createdate
  $scripts_github/tools/reset_file_timestamp.sh -p $d_path
fi

