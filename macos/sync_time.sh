#!/bin/sh
#
# for MacOS:
# 
# sync time w/ time server (runs under root's cron once a day)
# Note: this is needed since we disabled the ntpd daemon which runs in
# a sandbox in MacOS which does not allow reading resolv.conf thereby 
# does not sync time.
#
# Author:  Arul Selvan
# Version: Sep 5, 2014
#

log_file="${HOME}/tmp/sync_time.log"
# ntp client
ntp_client="/usr/bin/sntp -sS"
# use a list of servers so it works regardless of network (work or home)
time_servers="time.apple.com pool.ntp.org"

echo "Running time script ..." > $log_file
uid=`id -u`
if [ $uid -ne 0 ]; then
  echo "Need to run this in sudo" >> $log_file 2>&1
  exit
fi

for time_server in $time_servers; do
  /sbin/ping -t30 -c1 -qo $time_server >>$log_file 2>&1
  if [ $? -eq 0 ]; then 
    echo "Sync'ing time w/ server: $time_server" >> $log_file
    $ntp_client $time_server >> $log_file 2>&1
    exit
  fi
done
echo "Unable to reach any of the time servers: $time_servers" >> $log_file
