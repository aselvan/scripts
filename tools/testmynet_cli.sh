#!/bin/bash
#
# testmynet_cli.sh
#
# summary: simple shell script to test your ISP bandwidth using testmy.net servers.
# prereq: curl,bc,awk etc
#
# Author:  Arul Selvan
# Version: Jan 19, 2019
#
options_list="s:l:f:dh"
server=testmy.net
server_locations="dallas au ca co de fl in jp lax ny sf sg toronto uk"
size=102400 # default using 100MB 
location=dallas # default to dallas
user_agent="Wget/1.11.4" # testmy.net redirects to webpage if it sees curl :)
download_file="speedtest_file.html"
curl_opt="-L -k"
curl_silent="-s"
curl_opt_extra="-o /dev/null"
output_file=""
total_time=""
total_size=""
dns_time=""
connect_time=""
pretransfer_time=""
redirect_time=""
band_width=""
debug=0
url=""

# usage 
usage() {
  cat <<EOF

Usage: testmynet_cli.sh [options]
  
  options:
  -s  <size> download size in KB (default: $size i.e. 100MB)
  -l  <location> (default: dallas) see full list below
      $server_locations
  -f  <filename> speed information will be written out to 'filename'
  -d  debug messages, also saves the speedtest test downlod file as $download_file
  -h  help
EOF
  exit 1
}

debug_output() {
  echo "URL:              $url"
  echo "Downloaded file:  $download_file"
  echo "Total Time:       $total_time"
  echo "Total Size:       $total_size"
  echo "DNS Time:         $dns_time"
  echo "Connect Time:     $connect_time"
  echo "PreTransfer Time: $pretransfer_time"
  echo "Redirect Time:    $redirect_time"
  echo "Actual Total:     $actual_total i.e. (i.e. total_time-overhead like dns,connect, pretransfer, redirect etc)"
  echo "Bandwidth:        $band_width Mbps"
}

write_output() {
  m=$1
  if [ ! -z $output_file ] ; then
    echo $m >> $output_file
  else
    echo $m
  fi
}

# validate location 
check_location() {
  for l in $server_locations; do
    if [ "$location" = "$l" ] ; then 
      return
    fi
  done
  
  echo "[ERROR] location '$location' is invalid, see list below"
  usage
}

# calculate bandwidth and print out to stdout
calc_bandwidth() {
  stats=$1

  # split all the times
  total_time=`echo $stats | awk '{print $1}'`
  total_size=`echo $stats | awk '{print $2}'`
  dns_time=`echo $stats | awk '{print $3}'`
  connect_time=`echo $stats | awk '{print $4}'`
  pretransfer_time=`echo $stats | awk '{print $5}'`
  redirect_time=`echo $stats | awk '{print $6}'`

  # subtract overhead like dns, connect, redirect, etc from total time
  actual_total=$(scale=6; echo "$total_time - $dns_time - $connect_time - $pretransfer_time - $redirect_time"|/usr/bin/bc)

  # calculate the bandwidth i.e. ((total_size/(total_time-overhead)*8)/(1000*1000)
  band_width=$(scale=6; echo "($total_size/$actual_total)*8/(1000*1000)"|/usr/bin/bc)
  ts=$(date +"%D %H:%M %p")

  # spit out all calculated variables.
  if [ $debug -eq 1 ]; then
    debug_output
  fi

  write_output "[$ts] measured bandwidth: $band_width Mbps"
}

# check curl
which curl 2>&1 >/dev/null
if [ $? -ne 0 ] ; then
  echo "[ERROR] required curl binary missing or not in path!"
  exit 1
fi

while getopts "$options_list" opt; do
  case $opt in 
    s)
      size=$OPTARG
      ;;
    l)
      location=$OPTARG
      check_location
      ;;
    f)
      output_file=$OPTARG
      ;;
    d)
      debug=1
      curl_opt_extra="-o $download_file"
      curl_silent=""
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

# run curl and capture the stats.
url="https://${location}.${server}/dl-${size}"
stats=`curl $curl_opt $curl_silent $curl_opt_extra -A $user_agent -w "%{time_total} %{size_download} %{time_namelookup} %{time_connect} %{time_pretransfer} %{time_redirect}" $url`

calc_bandwidth "$stats"

