#!/usr/bin/env bash
#
# adb_push.sh --- simple wrapper over adb to copy files to phone.
#
# Note: in order for this script to work, you must pair your phone w/ adb first. If 
# there are multiple devices paired, you need to specifiy device name using -s option.
#
# Author:  Arul Selvan
# Version: Oct 30, 2023
#

# ensure path for cron runs
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

# version format YY.MM.DD
version=23.11.18
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="s:f:d:vh"
device=""
default_dest_dir="/sdcard"
dest_dir=""
source_path=""
no_such_file="No such file or directory"

usage() {
  cat << EOF
$my_name --- simple wrapper over adb to copy files to phone.
Usage: $my_name -s <device> -p <path> -d <dir> 
  -s <device> ---> andrioid device id of your phone paired with adb
  -f <path>   ---> file/path in computer to copy to phone
  -d <dir>    ---> destination dir in phone to copy files [Default: '$default_dest_dir'] 
  -v          ---> enable verbose, otherwise just errors/warnings are printed      
  -h help
  
  Examples: 
    $my_name -s pixel:5555 -f "/tmp/*.jpg" -d /sdcard/DCIM/Camera
EOF
  exit
}

check_device() {
  log.info "Check if the device ($device) is connected  ... "
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    case $d in 
      $device[:.]*)
        # must be a tcp device, attempt to connect
        log.info "This device ($device) is connected via TCP, attempting to connect ... "
        adb connect $device 2>&1 >> $my_logfile
        return
        ;;
      $device)
        # matched the full string could be USB or TCP (in case argument contains port)
        # if TCP make connection otherwise do nothing
        if [[ $device == *":"* ]] ; then
          log.info "This device ($device) is connected via TCP, attempting to connect ... "
          adb connect $device 2>&1 | tee -a $my_logfile
        else
          log.info "This device ($device) is connected via USB ... "
        fi
        return
        ;;
    esac
  done
  
  log.error "The specified device ($device) does not exist or connected!"
  exit 1
}

# check if destination dir is valid
check_dest_dir() {
  local output=$(adb $device shell ls $dest_dir 2>&1)
  if [[ $output = *"${no_such_file}"* ]] ; then
    log.error "The destination dir ($dest_dir) is not valid or does not exists!"
    exit 2
  fi
}

# copy files to destination path
push_path() {
  adb $device push $source_path ${dest_dir}/. 2>&1 | tee -a $my_logfile
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

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device="$OPTARG"
      check_device
      device="-s $device"
      ;;
    f)
      source_path="$OPTARG"
      ;;
    d)
      dest_dir="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# first get device count and see if anything is parired
device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
# if device count is 0 just exit
if [ $device_count -eq 0 ] ; then
  log.error "no devices are connected to adb, try pairing your phone."
  exit 1
fi

# check if adb connected to multiple devices but we don't have -s option
if [ $device_count -gt 1 ] && [ -z "$device" ] ; then
  log.error "More than one device connected to adb, please specify device to use with -s option"
  usage
  exit 2
fi

# if dest_path is not provided default $default_dest_dir
if [ -z $dest_dir ] ; then
  log.stat "Destination path not provided, using default path: $default_dest_dir"
  dest_dir=$default_dest_dir
fi

# ensure dest_path is valid and push files to phone
check_dest_dir
push_path

exit 0

