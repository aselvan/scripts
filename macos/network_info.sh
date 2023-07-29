#!/usr/bin/env bash
#
# network_info.sh --- Print simple network info (IP, MAC ... etc) of wired or wireless interface
#
# Though these info are readily available with different commandline tools on a Mac, this script
# is a handy one to use to get a simple output of all you need to know on your network device.
#
# Author:  Arul Selvan
# Created: Jul 29, 2023
#

# version format YY.MM.DD
version=23.07.29
my_name="`basename $0`"
my_version="`basename $0` v$version"
os_name=`uname -s`
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="ewvh?"
verbose=0
ssid=""
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -e         ---> print IP, MAC ... etc of a ethernet (wired) interface
     -w         ---> print IP, MAC ... etc of a WiFi (wireless) interface
     -v         ---> verbose mode prints info messages, otherwise just errors are printed
     -h         ---> print usage/help

  example: $my_name -w
  
EOF
  exit 0
}

write_log() {
  local msg_type=$1
  local msg=$2

  case $msg_type in
    # skip info if verbose is not set [default]
    info|INFO)
      if [ $verbose -eq 0 ] ; then
        return;
      fi
      echo -e "\e[1;36m[INFO]\e[0m $msg" | tee -a $log_file      
      ;;
    stat|STAT)
      echo -e "\e[1;34m[STAT]\e[0m $msg" | tee -a $log_file
      ;;
    warn|WARN)
      echo -e "\e[1;33m[WARN]\e[0m $msg" | tee -a $log_file
      ;;
    error|ERROR)
      echo -e "\e[1;31m[ERROR]\e[0m $msg" | tee -a $log_file
      ;;
  esac
}
init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "stat" "$my_version"
  write_log "info" "Running from: $my_path"
  write_log "info" "Start time:   `date +'%m/%d/%y %r'` ..."
}

print_info() {
  local dev_string=$1
  local net_dev=$(networksetup -listallhardwareports| awk "/Hardware Port: ${dev_string}/ {getline; print \$2}")
  if [ -z "$net_dev" ] ; then
    write_log "error" "Not able to determine your network interface!"
    exit 2
  fi
  write_log "info" "The network interface is '$net_dev'"
  lease_secs=`ipconfig getoption $net_dev lease_time`
  # read IP, MAC ... etc
  echo "    Interface:    $net_dev"
  echo "    Type:         $dev_string"
  echo "    Status:       `ifconfig $net_dev|awk '/status/ {print $2}'`"
  echo "    MAC Address:  `ifconfig $net_dev  | awk '/ether/ {print $2}'`"
  echo "    IP Address:   `ipconfig getifaddr $net_dev`"
  echo "    Mask:         `ipconfig getoption $net_dev subnet_mask`"
  echo "    DNS:          `ipconfig getoption $net_dev domain_name_server`"
  echo "    Gateway:      `ipconfig getoption $net_dev router`"
  echo "    Broadcast:    `ipconfig getoption $net_dev broadcast_address`"
  echo "    DHCP Lease:   `ipconfig getoption $net_dev lease_time` seconds"

  # if device is WiFi print additional info
  if [ "$dev_string" = "Wi-Fi" ] ; then
    rssi=`$airport -I |awk '/ agrCtlRSSI:/ {print $2}'`
    noise=`$airport -I |awk '/ agrCtlNoise:/ {print $2}'`
  echo "    WiFi Name:         `$airport -I |awk '/ SSID:/ {print $2}'`"
  echo "    WiFi Channel:      `$airport -I |awk '/ channel:/ {print $2}'`"
  echo "    WiFi Auth:         `$airport -I |awk '/ link auth:/ {print $3}'`"
  echo "    WiFi Channel:      `$airport -I |awk '/ channel:/ {print $2}'`"
  echo "    WiFI RSSI:         $rssi [range: (-100,0) note: closer to 0 is better, ex: -55 is pretty damn good]"
  echo "    WiFi Noise:        $noise [range: (-120,0) note: closer to -120 is better]"
  echo "    WiFi Quality:      $((rssi - noise)) [should be above 20]"
  echo "    WiFi Last TxnRate: `$airport -I |awk '/ lastTxRate:/ {print $2}'` mbps"
  fi

  exit 0
}

# ----------  main --------------
init_log
if [ "$os_name" != "Darwin" ] ; then
  write_log "error" "This script is intended to run on MacOS!"
  exit 1
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    w)
      print_info "Wi-Fi"
      ;;
    e)
      print_info "Ethernet"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# if no argument is provided, just show wifi
print_info "Wi-Fi"

