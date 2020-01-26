#!/bin/bash
# vfs_cache_pressure.sh --- check performace diff between 100 vs 50 for vfs_cache_pressure
#
# Author:  Arul Selvan
# Version: Jan 26, 2020
#

echo "Test cache pressure 100 vs 50"
sync
echo 3 > /proc/sys/vm/drop_caches
dd if=/dev/zero of=/tmp/testfile count=1 bs=900M >/dev/null 2>&1

sysctl -w vm.vfs_cache_pressure=100 >/dev/null 2>&1 
find / > /dev/null
cp /tmp/testfile /tmp/testfile2 >/dev/null 2>&1
echo "---------- Pressure = 100 ----------------"
time find / > /dev/null

sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1
find /  > /dev/null
echo "----------- Pressure = 50 ----------------"
cp /tmp/testfile2 /tmp/testfile3 >/dev/null 2>&1
time find / > /dev/null

rm -f /tmp/testfile /tmp/testfile2 /tmp/testfile3
