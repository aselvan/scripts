#!/bin/bash
#
# ad2unix_time.sh --- convert AD time to Unix human readble time
#
# Author:  Arul Selvan
# Version: Sep 25, 2021
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

# commandline arguments
options_list="t:h"
ad_timestamp=""

usage() {
  echo "Usage: $my_name -t <AD timestamp>"
  exit 0
}

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    t)
      ad_timestamp=$OPTARG
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

if [ -z $ad_timestamp ] ; then
  usage
fi
echo "[INFO] converting AD timestamp $ad_timestamp to human readable date ... " >$log_file 

# convert unix seconds
time_secs=$(echo "($ad_timestamp/10000000)-11644473600" | /usr/bin/bc)

# construct date it expires
readable_date=$(date -r $time_secs)

# subtract expiry_time_sec from today_sec and convert to calculate
# number of days left for password expiry
today_sec=$(/bin/date +%s)
num_days=$(echo "($time_secs - $today_sec)/60/60/24" | /usr/bin/bc)

echo "The timestamp represents '$readable_date' which is $num_days days from today" | tee -a $log_file
