#!/bin/bash
#
# google_home_light.sh --- handy script to run as cronjob (MacOS only) to turn on/off lights
# 
# The script uses macOS commandline tool to generate the google home voice command to be heard
# by the nearby google home device. Ofcourse in order for this to work, you need a google home 
# device nearby. We don't need any of this if the google home app 'routines' work as designed 
# but the stupid thing is buggy and often doesn't work or works at random time (not the scheduled 
# time) which makes it useless. This script would be cleaner if google enables the REST API 
# reverse engineered here (https://rithvikvibhu.github.io/GHLocalApi/) to send commands in 
# addition to voice but for some reason google hides that from developers.
#
# Author:  Arul Selvan
# Version: Dec 31, 2018
#
# Usage: See the sample (my own cron entries below).
# 
#lights on at 5.30pm'ish everyday
#30 17 * * * /Users/arul/src/scripts.github/google_home_light.sh livingroom on >/Users/arul/tmp/ghome.log 2>&1
#32 17 * * * /Users/arul/src/scripts.github/google_home_light.sh bedroom on >/Users/arul/tmp/ghome.log 2>&1
#
#lights off at 11.00pm'ish everyday
#00 23 * * * /Users/arul/src/scripts.github/google_home_light.sh livingroom off >/Users/arul/tmp/ghome.log 2>&1
#02 23 * * * /Users/arul/src/scripts.github/google_home_light.sh bedroom off >/Users/arul/tmp/ghome.log 2>&1
#

# light commands
LIVING_ROOM_ON="hey google, [[slnc 600]] turn on living room lights"
LIVING_ROOM_OFF="hey google, [[slnc 600]] turn off living room lights"
BED_ROOM_ON="hey google, [[slnc 600]] turn on bedroom lights"
BED_ROOM_OFF="hey google, [[slnc 600]] turn off bedroom lights"
LAMP_ON="hey google, [[slnc 600]] turn on bsl1"
LAMP_OFF="hey google, [[slnc 600]] turn off bsl1"
DEFAULT_VOLUME=40
script_name=`basename $0`

usage() {
	cat <<EOF
  
Usage: $script_name <room> <action> [volume]
  <room> valid options are "bedroom" or "livingroom"
  <action> valid options are "on" or "off"
  [volume] is 0-100 and is optional (default:38), increase if needed

EOF
  exit
}

# function to set speaker volume in macos
set_volume() {
  v=$1
  if [ ! -z $v ] ; then
    /usr/bin/osascript -e "set volume output volume $v"
  fi
}

# function to get current volume.
get_volume() {
  cur_volume=`/usr/bin/osascript -e "output volume of (get volume settings)"`
  echo "$cur_volume"
}

# turn on/off bedroom
bedroom() {
  action=$1
  volume=$2
  
  if [ ! -z $volume ] ; then
    set_volume $volume
  else
    set_volume $DEFAULT_VOLUME
  fi

  case $action in 
    on)
      echo $BED_ROOM_ON | /usr/bin/say
      sleep 5
      echo $LAMP_ON | /usr/bin/say
    ;;
    off)
      echo $BED_ROOM_OFF | /usr/bin/say
      sleep 5
      echo $LAMP_OFF | /usr/bin/say
    ;;
    *)
      echo "[ERROR] Unknown action: '$action'"
      usage
    ;;
  esac
}

# turn on/off livingroom
livingroom() {
  action=$1
  volume=$2
  
  if [ ! -z $volume ] ; then
    set_volume $volume
  else
    set_volume $DEFAULT_VOLUME
  fi
  
  case $action in 
    on)
      echo $LIVING_ROOM_ON | /usr/bin/say
    ;;
    off)
      echo $LIVING_ROOM_OFF | /usr/bin/say
    ;;
    *)
      echo "[ERROR] Unknown action: '$action'"
      usage
    ;;
  esac
}

# first, save the current volume so we can restore when we are done.
save_volume=$( get_volume )

# process commandline
case $1 in
  bedroom|livingroom) "$@"
  set_volume $save_volume
  ;;
  *)
  echo "[ERROR] Unknown option: '$1'"
  usage
  ;;
esac

exit 0
