#!/bin/bash
#
# ping_test.sh --- script to check latency, specifically devices on wifi network
#
# Can be run once, or extended period of times (see option -d) to check how latency
# varies by time of day, and other variables like devices in your home and neighbors
# homes etc. You can switch wifi channels and run for day to experiment which one works
# best for your wifi network. As new wifi access points and devices popup in your neighborhood,
# you have to repeat to choose a better channel or set your router to auto which in my
# experince does not work well, at least for me.
#
# Author:  Arul Selvan
# Version: Sep 5, 2014 (initial version)
# Version: Jun 27, 2022 (updated to have options, check for latency average, wifi channel check etc)
#
my_name=`basename $0`
os_name=`uname -s`
options="h:c:a:d:s:vw?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
verbose=0
ping_host="192.168.1.1"
ping_count=60
ping_avg_threshold=2
sleep_seconds=60
start_time=`date +%s`
current_time=0
duration=0
elappsed=0
check_wifi_channel=0
under_threshold=0
over_threshold=0
airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
iw_bin="/sbin/iw"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -h <host>    ---> ping host [default is '$ping_host']"
  echo "  -c <count>   ---> ping count [default is '$ping_count']"
  echo "  -a <value>   ---> ping average threshold to check [default is '$ping_avg_threshold']"
  echo "  -d <hours>   ---> how long (hours) to continually run? [default is just once and exit]"
  echo "  -s <seconds> ---> if duration set, how long to sleep between runs [default is '$sleep_seconds sec']"
  echo "  -w           ---> enable printing wifi channel to print [default is unset]"
  echo "  -v           ---> verbose mode prints info messages, otherwise just errors are printed"
  echo ""
  echo "example: $my_name -d $ping_host"
  echo ""
  exit 0
}

log() {
  local msg_type=$1
  local msg=$2

  # log info type only when verbose flag is set
  if [ "$msg_type" == "[INFO]" ] && [ $verbose -eq 0 ] ; then
    return
  fi

  echo "$msg_type $msg" | tee -a $log_file
}

check_host() {
  ping -t10 -c1 -nq $ping_host >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    log "[ERROR]" "$ping_host is a non-existant or invalid or unresponsive host!, check name and try again."
    exit 1
  fi
}


# get channel we are using if we are on wifi node 
get_channel() {
  local channel="N/A"

  # check if option set to check for wifi channel instead of blindly checking 
  # since we may be on wired network
  if [ $check_wifi_channel -eq 0 ]; then
    return
  fi

  if [ $os_name = "Darwin" ]; then
    if [ -e $airport_bin ] ; then
      channel=`$airport_bin -I |grep channel|sed -r 's/^.*c/C/g'`
    fi
  else
    if [ -e $iw_bin ] ; then
      iface=`$iw_bin dev | awk '$1=="Interface"{print $2}'`
      channel=`$iw_bin $iface info | awk '/channel/ {print $0}'`
    fi
  fi
  log "[STAT]" "wifi channel in use is: \"$channel\""
}

do_ping() {
  # set the pipefail to capture the status of ping properly 
  set -o pipefail
  result=(`ping -nq -c $ping_count $ping_host 2>&1 | awk -F' ' 'FNR == 4 {print $4} FNR == 5 {print $4}'`)
  status=$?
  if [ -z "$status" -o "$status" -ne 0 ]; then
    log "[ERROR]" "ping failed: status code=$status"
    exit
  fi

  received_packets=${result[0]}
  IFS='/' read -r min avg max std <<< "${result[1]}"

  if (( $(echo "$avg > $ping_avg_threshold" | bc -l) )); then
    log "[WARN]" "ping average of $avg ms exceeded threshold of $ping_avg_threshold ms at `date +%r`"
    ((over_threshold=over_threshold+1))
  else
    log "[INFO]" "ping average of $avg ms is within the expected threshold of $ping_avg_threshold ms"
    ((under_threshold=under_threshold+1))    
  fi

  if [ -z "$received_packets" -o "$received_packets" != $ping_count ]; then
    log "[WARN]" "ping packet loss,  $ping_count transmitted, $received_packets received"
  fi
}


# ----------  main --------------
if [ -f $log_file ] ; then
  rm $log_file
fi

# parse commandline options
while getopts $options opt; do
  case $opt in
    h)
      ping_host=$OPTARG
      ;;
    c)
      ping_count=$OPTARG
      ;;
    a)
      =$OPTARG
      ;;
    d)
      duration=$(echo "($OPTARG * 60 * 60)" | bc)
      ;;
    s)
      sleep_seconds=$OPTARG
      ;;
    v)
      verbose=1
      ;;
    w)
      check_wifi_channel=1
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
     esac
done

# start
check_host
log "[STAT]" "Starting $my_name ..."
log "[STAT]" "Start time: `date`"
if [ $duration -ne 0 ] ; then
  log "[STAT]" "Pinging host $ping_host $ping_count counts for each iteration for a period of $duration seconds ..."
else
  log "[STAT]" "Pinging host $ping_host $ping_count times ..."
fi
get_channel

# loop until we are done (should run just once if duration is not set i.e. 0)
while [ $elappsed -le $duration ] ; do
  # ping 
  do_ping
  
  # bail out if this is a single run
  if [ $duration -eq 0 ] ; then
    break
  fi

  # now sleep
  sleep $sleep_seconds

  # after run/sleep, calculate how much time left 
  current_time=`date +%s`
  elappsed=$(echo "$current_time - $start_time"|bc)
  #echo -e "\telappsed/duration:\t $elappsed/$duration"
done

total_runs=$(echo "$under_threshold + $over_threshold" | bc -l)
log "[STAT]" "Total Runs: $total_runs"
log "[STAT]" "Under $ping_avg_threshold ms:  $under_threshold"
log "[STAT]" "Over  $ping_avg_threshold ms:  $over_threshold"
log "[STAT]" "Percent under $ping_avg_threshold ms: $(echo "scale=3; ($under_threshold/$total_runs)*100" | bc -l)%"
log "[STAT]" "End time: `date`"
