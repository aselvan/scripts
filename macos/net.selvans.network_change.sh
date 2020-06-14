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

last_known_ip="/tmp/last_ip.txt"
lock_file="/tmp/network_change.loc"
log_file="/tmp/network_change.log"
home_server="selvans.net"
fw_script="/Users/aselvan/bin/pf/firewall"

cleanup_exit() {
  echo "[INFO] Ending $0 @ `date`" >> $log_file
  rm -f $lock_file
  exit 0
}

# add home server ip to firewall whitelist
add_home_server() {
  selvans_ip=`/usr/bin/dig +short $home_server`
  if [ $? -ne 0 ]; then
    echo "[ERROR] failed to get $home_server's IP,  skiping ..." >>$log_file
    return
  fi

  # check to make sure we got ip 
  failed=`echo $selvans_ip |awk '/[A-Za-z]/'`
  if [ ! -z $failed ]; then
    echo "[ERROR] $home_server's IP is invalid: $selvans_ip; skiping ..." >>$log_file
    return
  fi

  # all well, add to firewall rules.
  if [ -x $fw_script ] ; then
    # first flush old entries
    $fw_script flushtable >> $log_file 2>&1

    # now, add this IP
    echo "[INFO] executing $fw_script addtable $selvans_ip " >> $log_file
    $fw_script addip $selvans_ip >> $log_file 2>&1
  else
    echo "[ERROR] missing firewall script: $fw_script ; skipping ..." >> $log_file
  fi
}

# First sleep 15sec, otherwise launchd goes crazy restarting this script as it
# thinks (stupidly) that we are failing because we exited fast (in few seconds)
#
echo "[INFO] Starting $0 @ `date` ... " > $log_file
echo "[INFO] sleeping 15sec to keep launchd happy..." >> $log_file
sleep 15

# MacOS does not have flock so doing a poormans way of preventing parallel
# runs in case of resolv.conf changed w/ in 15 sec
if [ -f $lock_file ] ; then
  echo "[INFO] another instance of $0 is running, exiting." >> $log_file
  cleanup_exit
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
  cleanup_exit
fi

# check to make sure we got ip if not let the next try figure out
failed=`echo $new_ip |awk '/[A-Za-z]/'`
if [ ! -z $failed ]; then
  echo "[ERROR] No ip returned, will try next time $0 is executed" >>$log_file
  echo "[ERROR] Content: $new_ip" >> $log_file
  echo "[ERROR] Failed string=$failed" >>$log_file
  cleanup_exit
fi

# if IP is same as last time, just leave
if [ -f $last_known_ip ] ; then
  last_ip=`cat $last_known_ip`
  if [ "$last_ip" = "$new_ip" ] ; then
    echo "[INFO] new IP is same as last IP, not saving, exit." >> $log_file
    cleanup_exit
  fi
fi

echo "[INFO] External IP: $new_ip; saving to $last_known_ip " >> $log_file
echo $new_ip > $last_known_ip

# publish ip to our site
url="https://selvans.net/save/saveip.php?host=$myhostname&ip=$new_ip"
echo "[INFO] Publishing to: $url" >> $log_file
curl -s $url >> $log_file 2>&1

# finally, while we are at it, just add our external IP to the firewall whitelist
add_home_server

cleanup_exit
