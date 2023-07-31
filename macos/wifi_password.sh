#!/usr/bin/env bash
#
# wifi_password.sh --- handy script to read the wifi password from MacOS keychain
#
#
# Author:  Arul Selvan
# Created: Jul 28, 2023
#

# version format YY.MM.DD
version=23.07.28
my_name="`basename $0`"
my_version="`basename $0` v$version"
os_name=`uname -s`
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0

options="s:lvh?"
verbose=0
ssid=""
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -s <ssid>  ---> Your wifi ssid whose password you need to read
     -l         ---> List all the wifi SSIDs saved in your OS.
     -v         ---> verbose mode prints info messages, otherwise just errors are printed
     -h         ---> print usage/help

  example: $my_name -s MY_SSID
  
EOF
  exit 0
}

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
  echo -e "\e[0;34m$msg\e[0m" | tee -a $log_file 
}

log.warn() {
  log.init
  local msg=$1
  echo -e "\e[1;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[1;31m$msg\e[0m" | tee -a $log_file 
}

list_ssids() {
  # need to find out the WiFi device first as they are not always en0
  wifi_dev=$(networksetup -listallhardwareports| awk '/Hardware Port: Wi-Fi/{getline; print $2}')
  if [ -z $wifi_dev ] ; then
    log.error "Not able to determine your WiFi interface!"
    exit 2
  fi
  log.info "Your WiFi interface is '$wifi_dev'"
  log.info "Below is a list of WiFi SSIDs saved."

  networksetup -listpreferredwirelessnetworks $wifi_dev
  exit 0
}


# ----------  main --------------
log.init
if [ "$os_name" != "Darwin" ] ; then
  log.error "error" "This script is for MacOS only!"
  exit 1
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    v)
      verbose=1
      ;;
    s)
      ssid="$OPTARG"
      ;;
    l)
      list_ssids
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $ssid ] ; then
  log.stat "SSID not provided, attempting to determine currently connected SSID ..."
  ssid=`$airport -I |awk '/ SSID:/ {print $2}'`
  if [ -z "$ssid" ] ; then
    log.error "Unable to read current SSID!"
    exit 1
  fi
  log.info "Using SSID '$ssid'..."
fi

log.stat "Enter your MacOS username and password when prompted to continue ..."
password=$(security find-generic-password -ga $ssid 2>&1 >/dev/null|awk '/password:/ {print $2;}'|tr -d '"')
log.stat "SSID=$ssid  password=$password"

# copy password to paste buffer
echo $password|pbcopy
log.stat "Password is copied to paste buffer for convenience [Cmd+v to paste]"
