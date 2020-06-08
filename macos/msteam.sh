#!/bin/sh

#
# msteam.sh --- wrapper to avoid ms-team behave like a pig draining power and cpu
#
# In addition to disabling gpu usage, restrict msteam to not to compete with other 
# apps for cpu by lowering priority to the absolute minimum. In addition, if available, 
# and option is specified, this script will use 'cpulimit' tool to lock it down CPU usage 
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
cpu_percent=""
cpu_limit_bin=/usr/local/bin/cpulimit
options_list="l:h"
script_name=`basename $0`


usage() {
  echo "Usage: $script_name [-l <percent_cpu_limit>]"
  exit 1
}

# parse args
while getopts "$options_list" opt; do 
  case $opt in 
    l)
      cpu_percent=$OPTARG
      ;;
    h)
      usage
      ;;
    *)
      usage
     ;;
   esac
done

echo "[INFO] Starting MS-Team with gpu disabled."

# if cpulimit requested and tool is available, use it
if [[ ! -z $cpu_percent && -x $cpu_limit_bin ]] ; then
  echo "[INFO] using cpulimit tool to limit $cpu_percent% of CPU usage"
  $cpu_limit_bin -l $cpu_percent -i nice -n 20 nohup /Applications/Microsoft\ Teams.app/Contents/MacOS/Teams --disable-gpu > $log_file 2>&1 &
else
  nice -n 20 nohup /Applications/Microsoft\ Teams.app/Contents/MacOS/Teams --disable-gpu > $log_file 2>&1 &
fi
