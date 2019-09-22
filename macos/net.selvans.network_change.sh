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
# cp net.selvans.network_change.* /Library/LaunchAgents/
# chown root:wheel /Library/LaunchAgents/net.selvans.network_change.*
# 
# Author:  Arul Selvan
# Version: Sep 22, 2019
# OS: MacOS
# See also: net.selvans.network_change.plist
#

#
# check and update this mac's public IP
#
log_file="/tmp/network_change.log"
echo "[INFO] `date`: staring external IP check... " > $log_file
url="https://ifconfig.me/ip"
myhostname=`hostname`
new_ip=`curl -s https://ifconfig.me/ip`
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to detect exteral IP, status_code: $? " >> $log_file
  exit
fi

# check to make sure we got ip if not let the next try figure out
failed=`echo $new_ip |awk '/[A-Za-z]/'`
if [ ! -z $failed ]; then
  echo "[INFO] No ip returned, will try next time $0 is executed" >>$log_file
  echo "[INFO] Content: $new_ip" >> $log_file
  echo "[INFO] Failed string=$failed" >>$log_file
  exit
fi

echo "[INFO] External IP: $new_ip" >> $log_file
# publish ip to our site
url="https://selvans.net/save/saveip.php?host=$myhostname&ip=$new_ip"
echo "[INFO] Publishing to: $url" >> $log_file
curl -s $url >> $log_file 2>&1
