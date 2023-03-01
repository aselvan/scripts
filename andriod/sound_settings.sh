#!/bin/bash
#
# sound_settings.sh --- simple wrapper to set volume on andrioid phone
#
# Setup desired sound volume on different andriod sound devices like ringtone, media etc.
#
# Note: in order for this script to work, you must have paired your phone w/ adb first. If 
# there are multiple devices paried, you need to specifiy device name using -s option.
#
# Author:  Arul Selvan
# Version: Jan 6, 2018 --- original version
# Version: Mar 1, 2023 --- updated with option and support for andrioid 10 or later.
#
options_list="s:r:m:a:h"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
device=""
ring_vol=0
media_vol=0
alarm_vol=0
device_count=0

usage() {
  echo "Usage: $my_name [-s <device] [-r <value>] [-m <value>] [-a <value>]"
  echo "  -s <device> ---> andrioid device id of your phone paired with adb"
  echo "  -r <value>  ---> ringer volume level 0-7"
  echo "  -m <value>  ---> media volume level 0-25"
  echo "  -a <value>  ---> alaram volume level 0-7"
  echo "  -h help"
  exit
}

connect_device() {
  # attempt to connect
  echo "[INFO] attempting to connect to the device ($device) ... "| tee -a $log_file
  adb connect $device
}

check_device() {
  echo "[INFO] check if the device ($device) is connected  ... "| tee -a $log_file
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    if [[ $d == $device[:.]* ]]; then
      return
    fi
  done
  
  echo "[ERROR] the specified device ($device) does not exist or connected!" | tee -a $log_file
  exit 1
}

display_values() {
  vol=`adb $device shell cmd media_session volume --get --stream 5|awk '/volume is/ {print $4;}'`
  echo "[INFO] Ringer volume: $vol" | tee -a $log_file
  
  vol=`adb $device shell cmd media_session volume --get --stream 3|awk '/volume is/ {print $4;}'`
  echo "[INFO] Media volume: $vol" | tee -a $log_file

  vol=`adb $device shell cmd media_session volume --get --stream 4|awk '/volume is/ {print $4;}'`
  echo "[INFO] Alarm volume: $vol" | tee -a $log_file
}

# --------------- main ----------------------
echo "[INFO] `date`: $my_name starting ..." | tee $log_file

# first get device count
device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
# if device count is 0 just exit
if [ $device_count -eq 0 ] ; then
  echo "[ERROR] no devices are connected to adb, try pairing your phone." | tee -a $log_file
  exit 1
fi

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device=$OPTARG
      connect_device
      check_device
      device="-s $device"
      ;;
    r)
      ring_vol=$OPTARG

      ;;
    m)
      media_vol=$OPTARG
      ;;
    a)
      alarm_vol=$OPTARG
      ;;
    h)
      usage
      ;;
  esac
done

# check if adb connected to multiple devices but we don't have -s option
if [ $device_count -gt 1 ] && [ -z "$device" ] ; then
  echo "[ERROR] more than one device connected to adb, please specify device to use with -s option" | tee -a $log_file
  usage
  exit 2
fi

# if no options are specified, attempt to read the current values and display
if [ $ring_vol -eq 0 ] && [ $media_vol -eq 0 ] && [ $alarm_vol -eq 0 ] ; then
  display_values
  exit 0
fi

# can't change any volume settings if DnD is on
dnd_status=`adb -s $device shell settings get global zen_mode`
if [ $dnd_status -ne 0 ] ; then
  echo "[WARN] Do Not Distrub (DnD) is enabled, value=$dnd_status"| tee -a $log_file
  echo "[WARN] Can not adjust sound settings when DnD is on ... exiting."| tee -a $log_file
  exit 3
fi

# set the desired volume
if [ $ring_vol -ne 0 ] ; then
  echo "[INFO] setting ring volume to $ring_vol ..."| tee -a $log_file
  adb $device shell cmd media_session volume --set $ring_vol --stream 5 2>&1 | tee -a $log_file
fi

if [ $media_vol -ne 0 ] ; then
  echo "[INFO] setting media volume to $ring_vol ..."| tee -a $log_file
  adb $device shell cmd media_session volume --set $media_vol --stream 3 2>&1 | tee -a $log_file
fi

if [ $alarm_vol -ne 0 ] ; then
  echo "[INFO] setting media volume to $ring_vol ..."| tee -a $log_file
  adb $device shell cmd media_session volume --set $alarm_vol --stream 4 2>&1 | tee -a $log_file
fi

# read back the levels after the above change to show current values.
echo "[INFO] current volume level after adjusting ..." | tee -a $log_file
display_values

exit 0

