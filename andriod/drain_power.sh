#!/system/bin/sh

#
# Simple script to suck the battery out dry fast.
#
# Author: Arul Selvan
# Version: Oct 18, 2017
#
# Note: the mmc0 device driver sucks power so fast so just do a repeted file read
# to drian battery rapidly. First run 'cs' tool to disable charging and enable 
# when battery reaches 1%
#
# Note2: This cant be run in /sdcard/bin since it is not allowed to run from because
# of noexec mount of sdcard. So copy it to /data/local/; chmod +x and then run
#

log_file=/sdcard/tmp/battery_drain.log
battery_level=`cat /sys/class/power_supply/battery/capacity`

echo "Battery drain start..." > $log_file
echo "Battery Level: $battery_level" >> $log_file

# disable charging
echo 0 >/sys/class/power_supply/battery/charging_enabled

while [ $battery_level -gt 1 ] ;  do
  find / -name $battery_level >> /dev/null 2>&1
  battery_level=`cat /sys/class/power_supply/battery/capacity`
  echo "current battery level = $battery_level" >> $log_file
  echo "`date` : pausing for 2 sec ..." >> $log_file
  sleep 2
done

echo "battery drain done." >> $log_file
echo "current battery level = `cat /sys/class/power_supply/battery/capacity`" >> $log_file

# enable charging
echo 1 >/sys/class/power_supply/battery/charging_enabled
echo "Now battery should start charging..." >> $log_file
