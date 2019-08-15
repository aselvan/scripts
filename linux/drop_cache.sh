#!/bin/sh
#
# simple script to drop clean cache (memory and page)
#
# Author:  Arul Selvan
# Version: Jan 12, 2015

user=`id -u`
if [ $user -ne 0 ]; then
   echo "You need to be root to execute this script. Run w/ sudo"
   exit
fi

sync
echo "Before drop_caches:"
free -m
echo "Dropping clean memory and page cache..."
echo 3 >/proc/sys/vm/drop_caches
sleep 2
echo "After drop_caches:"
free -m
