#!/bin/bash
#
# phone_settings.sh --- simple wrapper to set volume on andrioid phone
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
# ensure path for utilities
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.03.02
my_name=`basename $0`
my_version="$my_name v$version"
options_list="s:r:m:a:w:lh"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
device=""
ring_vol=0
media_vol=0
alarm_vol=0
device_count=0
dnd_status=0
wifi_action=""

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
  Usage: $my_name [-s <device] [-r <value>] [-m <value>] [-a <value>] -w <disable|enable>
      -s <device> ---> andrioid device id of your phone paired with adb
      -r <value>  ---> ringer volume level 0-7
      -m <value>  ---> media volume level 0-25
      -a <value>  ---> alaram volume level 0-7
      -w <action> ---> action is "enable" turn on wifi or "disable" to turn it off
      -l          ---> list available devices
      -h help"

  Examples: 
    $my_name -s pixel:5555 -w enable
    $my_name -s pixel:5555 -r 5 -a 5
EOF
  exit
}

check_device() {
  echo "[INFO] check if the device ($device) is connected  ... "| tee -a $log_file
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    case $d in 
      $device[:.]*)
        # must be a tcp device, attempt to connect
        echo "[INFO] this device ($device) is connected via TCP, attempting to connect ... "| tee -a $log_file
        adb connect $device 2>&1 | tee -a $log_file
        return
        ;;
      $device)
        # matched the full string could be USB or TCP (in case argument contains port)
        # if TCP make connection otherwise do nothing
        if [[ $device == *":"* ]] ; then
          echo "[INFO] this device ($device) is connected via TCP, attempting to connect ... "| tee -a $log_file
          adb connect $device 2>&1 | tee -a $log_file
        else
          echo "[INFO] this device ($device) is connected via USB ... "| tee -a $log_file
        fi
        return
        ;;
    esac
  done
  
  echo "[ERROR] the specified device ($device) does not exist or connected!" | tee -a $log_file
  exit 1
}

list_devices() {
  devices=$(adb devices|awk 'NR>1 {print $1}')
  echo "[INFO] list of devices paired" | tee -a $log_file
  echo "$devices" | tee -a $log_file
}

display_values() {
  vol=`adb $device shell cmd media_session volume --get --stream 5|awk '/volume is/ {print $4;}'`
  echo "[INFO] Ringer volume: $vol" | tee -a $log_file
  
  vol=`adb $device shell cmd media_session volume --get --stream 3|awk '/volume is/ {print $4;}'`
  echo "[INFO] Media volume: $vol" | tee -a $log_file

  vol=`adb $device shell cmd media_session volume --get --stream 4|awk '/volume is/ {print $4;}'`
  echo "[INFO] Alarm volume: $vol" | tee -a $log_file

  if [ "$dnd_status" -eq 0 ] ; then
    echo "[INFO] DnD is: OFF" | tee -a $log_file
  else
    echo "[INFO] DnD is: ON" | tee -a $log_file
  fi
}

enable_disable_wifi() {
  if [[ "$wifi_action" != "enable" && "$wifi_action" != "disable" ]] ; then
    echo "[ERROR] Invalid -w argument. Must be 'enable' or 'disable'. See usage below" | tee -a $log_file
    usage
  fi
  adb $device shell "svc wifi $wifi_action"
}

# --------------- main ----------------------
echo "[INFO] $my_version starting ..." | tee $log_file

# first get device count and see if anything is parired
device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
# if device count is 0 just exit
if [ $device_count -eq 0 ] ; then
  echo "[ERROR] no devices are connected to adb, try pairing your phone." | tee -a $log_file
  exit 1
fi

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    l)
      list_devices
      exit 0
      ;;
    s)
      device=$OPTARG
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
    w)
      wifi_action=$OPTARG
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

# if this call is to enable/disable wifi just perform and exit
if [ ! -z "$wifi_action" ] ; then
  enable_disable_wifi
  exit 0
fi

dnd_status=`adb $device shell settings get global zen_mode`
# if no options are specified, attempt to read the current values and display
if [ $ring_vol -eq 0 ] && [ $media_vol -eq 0 ] && [ $alarm_vol -eq 0 ] ; then
  display_values
  exit 0
fi

# can't change any volume settings if DnD is on
if [ ! -z $dnd_status ] && [ $dnd_status -ne 0 ] ; then
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

