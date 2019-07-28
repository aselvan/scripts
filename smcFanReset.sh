#!/bin/sh
#
# smcFanReset.sh
#
# Simple script to use the smc tool to lower (or higher) fan speed by 
# forcing fan mode to 'manual' and return it back to 'auto' mode. The 
# Reason: Pre 2008 aluminum macbooks sensors sometime instruct fan to
# to go so fast even though the temp is not that high. Only run this
# script if the fan goes crazy fast. It should calm down after this
# script. The smc tool is available at github at link below.
#    https://github.com/hholtmann/smcFanControl/tree/master/smc-command
# 
# Author:  Arul Selvan
# Version: Nov 27, 2014
#
# Note: this must run as 'sudo' especially force fan mode to manual
#
smc=/Users/aselvan/bin/smc
log_file=/Users/kavitha/Desktop/fanspeed.txt

#
# Read CPU0 temperature 
#
echo "Manipulate/trick malfunctioning SMC temp/fan to run properly." > $log_file
echo "Run Time: `date`" >> $log_file
echo "" >> $log_file

# get current temp
echo "Current temp: " >> $log_file
$smc -k TC0D -r 2>&1 >> $log_file

# get current speed 
echo "Current speed: " >> $log_file
$smc -k F0Ac -r 2>&1 >> $log_file

# force fan mode to manual
echo "Forcing fan mode to 'manual' ..." >> $log_file
$smc -k "FS! " -w 0001 2>&1 >> $log_file

# set current speed to 4000 (i.e. python -c "print hex(4000 << 2)" = 3e80)
$smc -k F0Tg -w 3e80 2>&1 >> $log_file
echo "Forced fan to run at 4000rpm, reading value back below..." >> $log_file
$smc -k F0Tg -r 2>&1 >> $log_file

# reset it back to auto mode 
echo "Sleeping for 30 sec for fan to raise or lower speed..." >> $log_file
sleep 30
echo "Now, turning fan mode back to 'auto' ..." >> $log_file
$smc -k "FS! " -w 0000 2>&1 >> $log_file

echo "All Done" >> $log_file
chmod a+rw $log_file
