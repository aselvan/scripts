#!/bin/bash
#
# adb_wifi.sh --- simple wrapper script enable adb commands via wifi
#
# enables adb via TCP over wifi so we don't need to have phone connected
# with USB cable to laptop in order to connect to adb shell. This script 
# assumes adb is installed and is in the path.
#
# Steps:
#  * First connect your phone w/ USB cable
#  * Run 'adb_wifi.sh -l' to get a list of device IDs
#  * Now, run 'adb_wifi.sh -s <deviceID>', once it is succcesful, you can unplug phone
#  * From now on you, should be able to run adb_wifi.sh -c <device> adb_command
#
# Author: Arul Selvan
# Version: Oct 3, 2020
#
options_list="s:c:rlh"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
device=""
adb_default_tcp_port=5555

usage() {
  echo "Usage: $my_name [-s <device] | -l | [-c <device>] <adb_args>"
  echo "  -s <device> setup the specified deviceID for tcp connection"
  echo "  -c <device> execute the <adb_args> on the specifed/already setup device"
  echo "     NOTE: if there is just one device the -c option is not needed"
  echo "  -l show list of devices"
  echo "  -r restart adb service"
  echo "  -h help"
  exit
}

restart_adb() {
  echo "[INFO] restarting adb ..." | tee -a $log_file
  adb kill-server
  sleep 2
  adb start-server
  sleep 2
}

check_device() {
  # if device provided is an IP:port, just exit
  if  [[ $device == *[:.]* ]] ; then
    echo "[ERROR] specified device ($device) appear to be already connected"
    exit
  fi
  
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    if [ $d = $device ]; then
      return
    fi
  done
  
  echo "[ERROR] the specified device ($device) does not exist!"
  exit
}

setup() {
  check_device

  # for some reason adb does not show the device, just restart it once
  restart_adb

  echo "[INFO] setting up device $device ..." | tee -a $log_file
  adb -s $device tcpip $adb_default_tcp_port | tee -a $log_file

  sleep 2
  # list to show the device
  list
  exit
}

list() {
  echo "[INFO] available devices ..." | tee -a $log_file

  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    echo -e "\tdevice: $d" | tee -a $log_file
  done
  exit
}

# --------------- main ----------------------
echo "[INFO] `date`: $my_name starting ..." | tee $log_file
while getopts "$options_list" opt ; do
  case $opt in 
    c)
      device=$OPTARG
      shift $((OPTIND-1))
      break
      ;;
    s)
      device=$OPTARG
      setup
      ;;
    l)
      list $*
      ;;
    r)
      restart_adb
      exit
      ;;
    h)
      usage
      ;;
  esac
done

# if nothing specified, just print usage
if [ $# -eq 0 ] ; then
  echo "[ERROR] no commands specified!"
  usage
fi

if [ -z $device ]; then
  echo "[INFO] Executing ADB with out a device i.e. 'adb $*'" | tee -a $log_file
  exec adb $*
else
  echo "[INFO] Executing ADB with specified device i.e. 'adb -s $device $*'" | tee -a $log_file
  exec adb -s $device $*
fi
