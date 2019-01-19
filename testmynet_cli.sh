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
options_list="s:l:h"
server_domain=testmy.net
server_locations="au2 ca co de fl in jp lax ny sf sg tx uk"
size=102400 # default using 100MB 
location=tx
user_agent="Wget/1.11.4" # testmy.net redirects to webpage if it sees curl :)
curl_opt="-L -k -s -o /dev/null"

# usage 
usage() {
  cat <<EOF

Usage: testmynet_cli.sh [options]
  
  options:
  -s  <size> download size in KB (default: $size i.e. 100MB)
  -l  <location> (default: tx i.e. texas server) see full list below
      $server_locations
  -h  help
EOF
  exit 1
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
  echo "Your bandwidth is: $band_width Mbps"
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
url="https://${location}.${server_domain}/dl-${size}"
echo "Using server: $url"
stats=`curl $curl_opt -A $user_agent -w "%{time_total} %{size_download} %{time_namelookup} %{time_connect} %{time_pretransfer} %{time_redirect}" $url`
calc_bandwidth "$stats"

