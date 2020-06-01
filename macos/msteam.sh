#!/bin/sh

#
# msteam.sh --- wrapper to avoid ms-team behave like a pig draining power and cpu
#
# In addition to disabling gpu usage, restrict msteam to not to compete with other 
# apps for cpu by lowering priority to the absolute minimum. In addition, if available, 
# this script will use 'cpulimit' tool to lock it down CPU usage 
# 
# Optional: You can install the 'cpulimit' with Homebrew i.e. brew install cpulimit 
#
# Note: Most modern macs have 4 cores so the 100% (default value) will be limiting 
#       your msteam to use only 1 full CPU core, however msteam fork/exec's 4 child
#       process so in theory each process can get upto 100% CPU! so you can't win 
#       w/ this cpu pig! So the bottomline, it can potentially go up to 400% at the 
#       worst case but it doesnt seem to be going more than 100% which is good. 
#
# Author:  Arul Selvan
# Version: Jan 23, 2020
#

log_file=/tmp/msteam.log
cpu_percent=100
cpu_limit_bin=/usr/local/bin/cpulimit

echo "[INFO] Starting MS-Team with gpu disabled."

# if cpulimit present, use it
if [ -x $cpu_limit_bin ] ; then
  if [ ! -z $1 ] ; then
    cpu_percent=$1
  fi
  echo "[INFO] using cpulimit tool to limit $cpu_percent% of CPU usage"
  $cpu_limit_bin -l $cpu_percent -i nice -n 20 nohup /Applications/Microsoft\ Teams.app/Contents/MacOS/Teams --disable-gpu > $log_file 2>&1 &
else
  nice -n 20 nohup /Applications/Microsoft\ Teams.app/Contents/MacOS/Teams --disable-gpu > $log_file 2>&1 &
fi
