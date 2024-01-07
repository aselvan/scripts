#!/usr/bin/env bash
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
version=24.01.06
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="ADB wrapper script to set volume on andrioid phone"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="s:r:m:a:w:lvh"

# default to my phone so less typing :)  -Arul
device="arulspixel4"
ring_vol=0
media_vol=0
alarm_vol=0
device_count=0
dnd_status=0
wifi_action=""
device_offline="device offline"
failed="failed to connect"
not_found="not found"
con_refused="Connection refused"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name - $my_title
Usage: $my_name [-s <device] [-r <value>] [-m <value>] [-a <value>] -w <disable|enable>
  -s <device> ---> andrioid device id of your phone paired with adb
  -r <value>  ---> ringer volume level 0-7
  -m <value>  ---> media volume level 0-25
  -a <value>  ---> alaram volume level 0-7
  -w <action> ---> action is "enable" turn on wifi or "disable" to turn it off
  -v          ---> enable verbose, otherwise just errors are printed  
  -l          ---> list available devices
  -h help

  Examples: 
    $my_name -s pixel:5555 -w enable
    $my_name -s pixel:5555 -r3 -m3 -a5
EOF
  exit 0
}

check_device() {
  log.info "check if the device ($device) is connected  ... "
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    case $d in 
      $device[:.]*)
        # must be a tcp device, attempt to connect
        log.info "this device ($device) is connected via TCP, attempting to connect ... "
        output=$(adb connect $device 2>&1)
        if string_contains "$output" "$device_offline" ; then
          log.error "The device $device is offline, exiting."
          exit 2
        fi
        return
        ;;
      $device)
        # matched the full string could be USB or TCP (in case argument contains port)
        # if TCP make connection otherwise do nothing
        if [[ $device == *":"* ]] ; then
          log.info "this device ($device) is connected via TCP, attempting to connect ... "
          output=$(adb connect $device 2>&1)
          if string_contains "$output" "$device_offline" ; then
            log.error "The device $device is offline, exiting."
            exit 3
          fi
        else
          log.info "this device ($device) is connected via USB ... "
        fi
        return
        ;;
    esac
  done
  
  log.error "The specified device ($device) does not appear to be connected!"
  exit 1
}

list_devices() {
  devices=$(adb devices|awk 'NR>1 {print $1}')
  log.stat "list of devices paired" $black
  log.stat "$devices" $green
}

display_values() {
  vol=`adb $device shell cmd media_session volume --get --stream 5|awk '/volume is/ {print $4;}'`
  log.stat "  Ringer volume: $vol"
  
  vol=`adb $device shell cmd media_session volume --get --stream 3|awk '/volume is/ {print $4;}'`
  log.stat "  Media volume: $vol"

  vol=`adb $device shell cmd media_session volume --get --stream 4|awk '/volume is/ {print $4;}'`
  log.stat "  Alarm volume: $vol"

  if [ "$dnd_status" -eq 0 ] ; then
    log.stat "  DnD is: OFF"
  else
    log.stat "  DnD is: ON"
  fi
}

enable_disable_wifi() {
  if [[ "$wifi_action" != "enable" && "$wifi_action" != "disable" ]] ; then
    log.error "Invalid -w argument. Must be 'enable' or 'disable'. See usage below"
    usage
  fi
  adb $device shell "svc wifi $wifi_action"
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# first get device count and see if anything is parired
device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
# if device count is 0 just exit
if [ $device_count -eq 0 ] ; then
  log.error "no devices are connected to adb, try pairing your phone."
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

# check if adb connected to multiple devices but we don't have -s option
if [ $device_count -gt 1 ] && [ -z "$device" ] ; then
  log.error "More than one device connected to adb, please specify device to use with -s option" 
  usage
  exit 2
fi

# if this call is to enable/disable wifi just perform and exit
if [ ! -z "$wifi_action" ] ; then
  enable_disable_wifi
  exit 0
fi

dnd_status=`adb $device shell settings get global zen_mode`
if string_contains "$dnd_status" "$not_found" ; then
  log.error "Unable to read DnD status. error: '$dnd_status'"
  exit 4
fi
# if no options are specified, attempt to read the current values and display
if [ $ring_vol -eq 0 ] && [ $media_vol -eq 0 ] && [ $alarm_vol -eq 0 ] ; then
  display_values
  exit 0
fi

# can't change any volume settings if DnD is on
if [ ! -z "$dnd_status" ] && [ "$dnd_status" -ne 0 ] ; then
  log.warn "Do Not Distrub (DnD) is enabled, value=$dnd_status"
  log.warn "Can not adjust sound settings when DnD is on ... exiting."
  exit 3
fi

# set the desired volume
if [ $ring_vol -ne 0 ] ; then
  log.stat "setting ring volume to $ring_vol ..."
  adb $device shell cmd media_session volume --set $ring_vol --stream 5 2>&1 >> $my_logfile
fi

if [ $media_vol -ne 0 ] ; then
  log.info "setting media volume to $ring_vol ..."
  adb $device shell cmd media_session volume --set $media_vol --stream 3 2>&1 >> $my_logfile
fi

if [ $alarm_vol -ne 0 ] ; then
  log.info "setting media volume to $ring_vol ..."
  adb $device shell cmd media_session volume --set $alarm_vol --stream 4 2>&1 >> $my_logfile
fi

# read back the levels after the above change to show current values.
log.info "Current volume level after adjusting ..."
display_values

exit 0

