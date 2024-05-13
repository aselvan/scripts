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

check_os() {
  if [ $os_name != "Linux" ] ; then
    log.error "This script is meant for Linux OS only!"
    exit 1
  fi
}

list_fs_devices() {
  fs_dev_list=`ls /dev/sd?[0-9]`

  for d in $fs_dev_list ; do
    log.stat "  Device: $d"
    if ! findmnt -n $d 2>&1 >/dev/null ; then
      log.warn "    Mounted: False"
      continue
    fi
    log.stat  "    Mounted: True"
    output=$(findmnt -n $d --output=size,avail|awk '{print $1,"/",$2}')
    log.stat "    Total/Available: $output" 
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

