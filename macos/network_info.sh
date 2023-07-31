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
log_init=0
options="i:ewvh?"
verbose=0
ssid=""
net_dev="en0"
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -i <interface> ---> show details of specified interface [example: en0, en1...etc]
     -e             ---> show details of wired interface [on multi-homed, first device shown]
     -w             ---> show details of wireless interface [on multi-homed, first device shown]
     -v             ---> verbose mode prints info messages, otherwise just errors are printed
     -h             ---> print usage/help

  example: $my_name -w
  
EOF
  exit 0
}

log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}

log.stat() {
  log.init
  local msg=$1
  echo -e "\e[0;34m$msg\e[0m" | tee -a $log_file 
}

log.warn() {
  log.init
  local msg=$1
  echo -e "\e[1;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[1;31m$msg\e[0m" | tee -a $log_file 
}

get_interface() {
  local dev_string=$1
  net_dev=$(networksetup -listallhardwareports| awk "/Hardware Port: ${dev_string}/ {getline; print \$2}")
  if [ -z "$net_dev" ] ; then
    log.error "Not able to determine your network interface!"
    exit 2
  fi
  log.info "The network interface is '$net_dev'"
}

print_info() {
  local dev_string=$1
  lease_secs=`ipconfig getoption $net_dev lease_time`
  log.stat "Total number of interfaces available: `ipconfig ifcount`"
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
    echo "    WiFi Quality:      $((rssi - noise)) [should be at least 20 or greater]"
    echo "    WiFi Last TxnRate: `$airport -I |awk '/ lastTxRate:/ {print $2}'` mbps"
  fi

  exit 0
}

# ----------  main --------------
log.init
if [ "$os_name" != "Darwin" ] ; then
  log.error "This script is intended to run on MacOS!"
  exit 1
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    w)
      get_interface "Wi-Fi"
      print_info "Wi-Fi"
      ;;
    e)
      get_interface "Ethernet"
      print_info "Ethernet"
      ;;
    i)
      net_dev="$OPTARG"
      # see if this is a wired or wireless
      networksetup -getairportnetwork $net_dev 2>&1 >/dev/null
      if [ $? -eq 0 ] ; then
        print_info "Wi-Fi"
      else
        print_info "Ethernet/Other"
      fi
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
get_interface "Wi-Fi"
print_info "Wi-Fi"
