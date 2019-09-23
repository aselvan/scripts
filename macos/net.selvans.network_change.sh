#!/bin/bash
#
# net.selvans.network_change.sh --- this script runs when network changed.
#
# Description:
# This script is run by net.selvans.network_change.plist installed on your macOS to watch
# changes to /etc/resolv.conf i.e. whenever a new IP is assigned. This script
# will save the IP to track where the mac is connected.
#
# Install steps:
# cp net.selvans.network_change.* /Library/LaunchDaemons/
# chown root:wheel /Library/LaunchDaemons/net.selvans.network_change.*
# 
# Author:  Arul Selvan
# Version: Sep 22, 2019
# OS: MacOS
# See also: net.selvans.network_change.plist
#

lock_file="/tmp/network_change.loc"
log_file="/tmp/network_change.log"
echo "[INFO] Starting $0 @ `date` ... " > $log_file


# First sleep 15sec, otherwise launchd goes crazy restarting this script as it
# thinks (stupidly) that we are failing because we exited fast (in few seconds)
#
echo "[INFO] sleeping 15sec to keep launchd happy..." >> $log_file
sleep 15

# MacOS does not have flock so doing a poormans way of preventing parallel
# runs in case of resolv.conf changed w/ in 15 sec
if [ -f $lock_file ] ; then
  echo "[INFO] another instance of $0 is running, exiting." >> $log_file
  exit 0
else
  touch $lock_file
fi

#
# check and update this mac's public IP
#
url="https://ifconfig.me/ip"
myhostname=`hostname`
new_ip=`curl -s https://ifconfig.me/ip`
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to detect exteral IP, status_code: $? " >> $log_file
  rm -f $lock_file
  exit 0
fi

# check to make sure we got ip if not let the next try figure out
failed=`echo $new_ip |awk '/[A-Za-z]/'`
if [ ! -z $failed ]; then
  echo "[INFO] No ip returned, will try next time $0 is executed" >>$log_file
  echo "[INFO] Content: $new_ip" >> $log_file
  echo "[INFO] Failed string=$failed" >>$log_file
  rm -f $lock_file
  exit 0
fi

echo "[INFO] External IP: $new_ip" >> $log_file
# publish ip to our site
url="https://selvans.net/save/saveip.php?host=$myhostname&ip=$new_ip"
echo "[INFO] Publishing to: $url" >> $log_file
curl -s $url >> $log_file 2>&1

echo "[INFO] Ending $0 @ `date`" >> $log_file
rm -f $lock_file
exit 0
