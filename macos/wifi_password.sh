#!/usr/bin/env bash
################################################################################
#
# wifi_password.sh --- Read the wifi password from MacOS keychain
#
#
# Author:  Arul Selvan
# Created: Jul 28, 2023
#
################################################################################
# Version History:
#   July 28, 2023 --- Original version
#   Feb  20, 2025 --- Use standard includes, remove depricated airport command
# 
################################################################################

# version format YY.MM.DD
version=25.02.20
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Read the wifi password from MacOS keychain"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:lvh?"
ssid=""
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -s <ssid>  ---> Your wifi SSID whose password you need to read 
  -l         ---> List all the wifi SSIDs saved in your WiFi preferences
  -v         ---> verbose mode prints info messages, otherwise just errors are printed
  -h         ---> print usage/help

example:
  $my_name -s MY_SSID
  
EOF
  exit 0
}

list_ssids() {
  # need to find out the WiFi device first as they are not always en0
  wifi_dev=$(networksetup -listallhardwareports| awk '/Hardware Port: Wi-Fi/{getline; print $2}')
  if [ -z $wifi_dev ] ; then
    log.error "Not able to determine your WiFi interface!"
    exit 2
  fi
  log.stat "List of SSIDs for your Wi-Fi interface: '$wifi_dev'"
  networksetup -listpreferredwirelessnetworks $wifi_dev
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

if [ "$os_name" != "Darwin" ] ; then
  log.error "error" "This script is for MacOS only!"
  exit 0
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    s)
      ssid="$OPTARG"
      ;;
    l)
      list_ssids
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $ssid ] ; then
  log.stat "SSID not provided, attempting to determine currently connected SSID ..."
  ssid=`system_profiler SPAirPortDataType | awk '/Current Network Information/{getline; print $1; exit}'|tr -d ':'`
  if [ -z "$ssid" ] ; then
    log.error "Unable to read current SSID!"
    exit 1
  fi
  log.stat "Using SSID: '$ssid'..."
fi

log.stat "Enter your MacOS username and password when prompted ..."
password=$(security find-generic-password -ga $ssid 2>&1 >/dev/null|awk '/password:/ {print $2;}'|tr -d '"')
log.stat "SSID ($ssid) password: $password"

# copy password to paste buffer
echo $password|pbcopy
log.stat "Password is also copied to paste buffer for convenience [cmd+v to paste]"
