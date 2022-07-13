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
# note: if PINGTEST_EMAIL_FROM, PINGTEST_EMAIL_TO env variable set, script will e-mai;
# if the latency average is poor during the runs i.e. less than $percent_limit setting
#
# Author:  Arul Selvan
# Version: Sep 5, 2014 (initial version)
# Version: Jun 27, 2022 (updated to have options, check for latency average, wifi channel check etc)
#
my_name=`basename $0`
os_name=`uname -s`
host_name=`hostname`
options="h:c:a:d:s:l:vw?"
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
# we will grab this from environment PINGTEST_EMAIL_FROM, PINGTEST_EMAIL_TO
email_from=$PINGTEST_EMAIL_FROM
email_to=$PINGTEST_EMAIL_TO
email_subject="Low network latency seen"
percent_limit=95

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -h <host>    ---> ping host [default is '$ping_host']"
  echo "  -c <count>   ---> ping count [default is '$ping_count']"
  echo "  -a <value>   ---> ping average millisecond threshold to check [default is '$ping_avg_threshold' ms]"
  echo "  -d <hours>   ---> how long (hours) to continually run? [default is just once and exit]"
  echo "  -s <seconds> ---> if duration set, how long to sleep between runs [default is '$sleep_seconds sec']"
  echo "  -l <logfile> ---> optional log file name to write output [default is '$log_file']"
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
  local rc=0
  ping -t10 -c1 -nq $ping_host >/dev/null 2>&1
  rc=$?
  if [ $rc -ne 0 ] ; then
    log "[ERROR]" "$ping_host is a non-existant or invalid or unresponsive host!, check name and try again. error=$rc"
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
      if [ ! -z $iface ] ; then
        channel=`$iw_bin $iface info | awk '/channel/ {print $0}'`
      fi
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

do_email() {
  local msg=$1
  if [ $os_name = "Darwin" ]; then
    sub_and_from=$(echo -e "$email_subject\nFrom: $email_from\n")
    echo $msg | mail -s "$sub_and_from"  $email_to
  else
    echo $msg | mail -s "$email_subject" --append "From: $email_from" $email_to
  fi
}

# ----------  main --------------
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
      ping_avg_threshold=$OPTARG
      ;;
    d)
      duration=$(echo "($OPTARG * 60 * 60)" | bc)
      ;;
    s)
      sleep_seconds=$OPTARG
      ;;
    l)
      log_file=$OPTARG
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

if [ -f $log_file ] ; then
  rm $log_file
fi

# start
cmdline_args=`printf "%s " $@`
check_host
log "[STAT]" "$my_name $cmdline_args"
log "[STAT]" "Start time: `date`"
log "[STAT]" "Ping count:     $ping_count"
log "[STAT]" "Sleep seconds:  $sleep_seconds seconds"
log "[STAT]" "Ping threshold: $ping_avg_threshold ms"
if [ $duration -ne 0 ] ; then
  log "[STAT]" "Duration: continually run for $duration seconds"
else
  log "[STAT]" "Duration: run once and exit"
fi
get_channel
log "[STAT]" "Pinging '$ping_host' from '$host_name' ..."

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
percent_under=`printf %.f $(echo "($under_threshold/$total_runs)*100" | bc -l)`
log "[STAT]" "Total Runs: $total_runs"
log "[STAT]" "Under $ping_avg_threshold ms:  $under_threshold"
log "[STAT]" "Over  $ping_avg_threshold ms:  $over_threshold"
log "[STAT]" "Percent under $ping_avg_threshold ms: $percent_under %"

if [ $percent_under -le $percent_limit ] ; then 
  log "[WARN]" "observed latency percent of ${percent_under}% is less than ${percent_limit}%"
  # email if env variables are set
  if [ ! -z $email_from ] && [ ! -z $email_to ]  ; then
    do_email "observed latency percent of ${percent_under}% is less than ${percent_limit}%"
  fi
fi

log "[STAT]" "End time: `date`"
log "[STAT]" "$my_name output is written to file at $log_file"
