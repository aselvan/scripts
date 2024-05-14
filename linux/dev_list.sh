#!/usr/bin/env bash
#
# dev_list.sh --- List valid fs devices and their size
#
#
# Author:  Arul Selvan
# Created: May 13, 2024
#
# Version History:
#   May 13, 2024 --- Initial version
#   May 14, 2024 --- Get additional info for device like model,vendor,size etc.

# version format YY.MM.DD
version=24.05.13
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="List valid fs devices and their size"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="vh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name
  
EOF
  exit 0
}

get_model() {
  local d=$1
  local m=`udevadm info --query=property --name=$d | grep ID_MODEL= | awk -F= '{print $2}'`
  if [ -z $m ] ; then
    m=`udevadm info --query=property --name=$d | grep ID_USB_MODEL= | awk -F= '{print $2}'`
  fi
  echo $m
}

get_vendor() {
  local d=$1
  local v=`udevadm info --query=property --name=$d | grep ID_VENDOR= | awk -F= '{print $2}'`
  if [ -z $v ] ; then
    v=`udevadm info --query=property --name=$d | grep ID_USB_VENDOR= | awk -F= '{print $2}'`
  fi
  echo $v
}

get_size() {
  local d=$1
  local s=`udevadm info --query=property --name=$d | grep ID_FS_SIZE= | awk -F= '{print $2}'`
  if [ -z $s ] ; then
    s="N/A"
  else
    s="$(byte2gb $s)G"
  fi
  echo $s
}


check_os() {
  if [ $os_name != "Linux" ] ; then
    log.error "This script is meant for Linux OS only!"
    exit 1
  fi
}

list_fs_devices() {

  log.stat ""
  log.stat "List of storage devices"
  
  fs_dev_list=`ls /dev/sd?[0-9]`
  for d in $fs_dev_list ; do
    log.stat "  Device: $d"
    log.stat "  Model: $(get_model $d)"
    log.stat "  Vendor: $(get_vendor $d)"
    log.stat "  Size:   $(get_size $d)"
    if ! findmnt -n $d 2>&1 >/dev/null ; then
      log.stat "  Mounted: False" $grey
      log.stat ""
      continue
    fi
    log.stat  "  Mounted: True" $green
    output=$(findmnt -n $d --output=avail)
    log.stat "  Free: $output" 
    log.stat ""
  done
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
while getopts $options opt ; do
  case $opt in
    v)
      verbose=1
      ;;
    e)
      email_address="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

check_os
check_root
list_fs_devices

