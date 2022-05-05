#!/system/bin/sh
#
# turn on/off airplane mode
#
# Can be used in cron to turn off aiplane mode at night to avoid RF signal
# transmission since phone is close to bedside.
#
# Author:  Arul Selvan
# Version: Dec 22, 2017
#

function usage() {
  echo "Usage: $0 <on>|<off>"
  exit
}

if [ $# -lt 1 ]; then
  usage
fi

if [ $1 = "on" ]; then
  echo "Turning on airplane mode"
  /system/bin/settings put global airplane_mode_on 1
  /system/bin/am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
elif [ $1 = "off" ]; then
  echo "Turning off airplane mode"
  /system/bin/settings put global airplane_mode_on 0
  /system/bin/am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
else
  echo "Unknown option: $1"
  usage
fi
