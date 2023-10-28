#!/usr/bin/env bash
#
# adb_rm.sh --- simple wrapper over adb to delete files/directory.
#
# Note: in order for this script to work, you must pair your phone w/ adb first. If 
# there are multiple devices paired, you need to specifiy device name using -s option.
#
# Author:  Arul Selvan
# Version: Oct 27, 2023
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.10.27
my_name=`basename $0`
my_version="$my_name v$version"
options_list="s:r:vh"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
verbose=0
failure=0
green=32
red=31
blue=34

device=""
default_remove_location="/sdcard/DCIM/Camera"
remove_location=""

usage() {
  cat << EOF
$my_name --- simple wrapper over adb to delete files/directory from phone.
Usage: $my_name -s <device> -l <path> -r <path> [-d <path>] [-w <wildcard>] 
  -s <device>   ---> andrioid device id of your phone paired with adb
  -r <path>     ---> delete everything under that path [Default: '$default_remove_location']
  -v            ---> verbose mode prints info messages, otherwise just errors/warnings are printed      
  -h help
  
  Examples: 
    $my_name -s pixel:5555 -r /sdcard/DCIM/Camera
    $my_name -s pixel:5555 -r "/sdcard/DCIM/Camera/*.jpg"
EOF
  exit
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

check_device() {
  log.info "Check if the device ($device) is connected  ... "
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    case $d in 
      $device[:.]*)
        # must be a tcp device, attempt to connect
        log.info "This device ($device) is connected via TCP, attempting to connect ... "
        adb connect $device 2>&1 | tee -a $log_file
        return
        ;;
      $device)
        # matched the full string could be USB or TCP (in case argument contains port)
        # if TCP make connection otherwise do nothing
        if [[ $device == *":"* ]] ; then
          log.info "This device ($device) is connected via TCP, attempting to connect ... "
          adb connect $device 2>&1 | tee -a $log_file
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

confirm_action() {
  local msg=$1
  log.stat "$msg"
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    log.warn "Deleting..."
    return
  else
    log.stat "Remove canceled, exiting..."
    exit 9
  fi
}

remove_path() {
  confirm_action "Removing everything under this path: '$remove_location'"
  adb $device shell rm -rf $remove_location  2>&1 | tee -a $log_file
  adb $device shell sync 2>&1 | tee -a $log_file
}


# --------------- main ----------------------
log.init
# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device="$OPTARG"
      check_device
      device="-s $device"
      ;;
    r)
      remove_location="$OPTARG"
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

if [ -z "$remove_location" ] ; then 
  remove_location=$default_remove_location
fi

# remove it
remove_path

exit 0

