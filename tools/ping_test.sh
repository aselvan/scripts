#!/bin/sh
#
# Author:  Arul Selvan
# Version: Sep 5, 2014
#

dest=google.com
status_file=~/pingstatus.txt
ping_count=30
sleep_sec=5
repeat=10

echo "Ping test to $dest ..."
# do a ping for 30 count and report any failure, sleep 30 sec and repeat
for (( i=0; i<$repeat; i++)) do 
  result=`ping -q -c $ping_count $dest 2>&1 |grep received |awk '{print $4;}'`
  status=$?
  if [ -z "$status" -o "$status" != "0" ]; then
    echo "`date` : ping failed: status code=$status" >> $status_file
  fi
  if [ -z "$result" -o "$result" != $ping_count ]; then
    echo "`date` : packet loss: $ping_count transmitted, $result received" >> $status_file
  fi
  sleep $sleep_sec
done
