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

write_log() {
  local msg_type=$1
  local msg=$2

  case $msg_type in
    # skip info if verbose is not set [default]
    info|INFO)
      if [ $verbose -eq 0 ] ; then
        return;
      fi
      echo -e "\e[1;36m[INFO]\e[0m $msg" | tee -a $log_file      
      ;;
    stat|STAT)
      echo -e "\e[1;34m[STAT]\e[0m $msg" | tee -a $log_file
      ;;
    warn|WARN)
      echo -e "\e[1;33m[WARN]\e[0m $msg" | tee -a $log_file
      ;;
    error|ERROR)
      echo -e "\e[1;31m[ERROR]\e[0m $msg" | tee -a $log_file
      ;;
  esac
}
init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "stat" "$my_version"
  write_log "info" "Running from: $my_path"
  write_log "info" "Start time:   `date +'%m/%d/%y %r'` ..."
}

list_ssids() {
  # need to find out the WiFi device first as they are not always en0
  wifi_dev=$(networksetup -listallhardwareports| awk '/Hardware Port: Wi-Fi/{getline; print $2}')
  if [ -z $wifi_dev ] ; then
    write_log "error" "Not able to determine your WiFi interface!"
    exit 2
  fi
  write_log "info" "Your WiFi interface is '$wifi_dev'"
  write_log "stat" "Below is a list of WiFi SSIDs saved."

  networksetup -listpreferredwirelessnetworks $wifi_dev
  exit 0
}



# ----------  main --------------
init_log
if [ "$os_name" != "Darwin" ] ; then
  write_log "error" "This script only works on MacOS!"
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
  write_log "stat" "SSID not provided, attempting to determine currently connected SSID ..."
  ssid=`$airport -I |awk '/ SSID:/ {print $2}'`
  if [ -z "$ssid" ] ; then
    write_log "error" "Unable to read current SSID!"
    exit 1
  fi
  write_log "stat" "Using SSID '$ssid'..."
fi

write_log "stat" "Enter your MacOS username and password when prompted to continue ..."
password=$(security find-generic-password -ga $ssid 2>&1 >/dev/null|awk '/password:/ {print $2;}'|tr -d '"')
echo "SSID=$ssid  password=$password"
