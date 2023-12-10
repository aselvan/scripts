#!/usr/bin/env bash
#
# adb_rm.sh --- simple wrapper over adb to list file/dir
#
# Note: in order for this script to work, you must pair your phone w/ adb first. If 
# there are multiple devices paired, you need to specifiy device name using -s option.
#
# Author:  Arul Selvan
# Version: Dec 10, 2023
#


# version format YY.MM.DD
version=23.12.10
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="s:p:vh"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# default to my phone so less typing -Arul
device="arulspixel7"
default_ls_path="/sdcard/DCIM/Camera"
ls_path=""

usage() {
  cat << EOF
$my_name --- simple wrapper over adb to delete files/directory from phone.
Usage: $my_name -s <device> -l <path> -r <path> [-d <path>] [-w <wildcard>] 
  -s <device>   ---> andrioid device id of your phone paired with adb
  -p <path>     ---> do a ls -l on path [Default: '$default_ls_path']
  -v            ---> enable verbose, otherwise just errors/warnings are printed      
  -h help
  
  Examples: 
    $my_name -s pixel:5555 -p /sdcard/DCIM/Camera
    $my_name -s pixel:5555 -p "/sdcard/DCIM/Camera/*.jpg"
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
        adb connect $device 2>&1 | tee -a $my_logfile
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

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
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
      ;;
    p)
      ls_path="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check the device
check_device
device="-s $device"

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

if [ -z "$ls_path" ] ; then 
  ls_path=$default_ls_path
fi

# do ls
adb $device shell ls -l $ls_path  2>&1 | tee -a $my_logfile

exit 0

