#!/bin/bash
#
# apache_version_check.sh --- quick and dirty script to check apache version.
#
# Author:  Arul Selvan
# version: Oct 6, 2021
#

my_name=`basename $0`
run_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="p:s:h"

# fill in your desired IP/host and port where apache might be running.
servers="192.168.1.1,192.168.1.2,192.168.1.3, trex "
ports="80,443,8080"

usage() {
  echo "Usage: $my_name [options]"
  echo "  -s <hosts/ips> --- comma separated list of hostname or IPs [defaut: $servers]"
  echo "  -p <ports>     --- comma separated list of ports [default: $ports]"
  exit 0
}

# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    s)
      servers=$OPTARG
      ;;
    p)
      ports=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

ts=$(date +"%D %H:%M %p")
echo "[INFO] $my_name starting at [$ts] ... " |/usr/bin/tee $run_logfile

IFS=","
for s in $servers ; do
  s=`echo $s|tr -d ' '`
  echo "Checking server: $s" | tee -a $run_logfile
  for p in $ports ; do
    p=`echo $p|tr -d ' '`
    v=`curl -m2 -vs $s:$p 2>&1|awk '/Server:/ {print $3;}'`
    if [ -z $v ]; then
      v="N/A"
    fi
    echo -e "\tPort:Version: $p:$v" | tee -a $run_logfile
  done
done

