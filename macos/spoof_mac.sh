#/bin/sh
#
# spoof_mac.sh
#
# Description: 
#  Spoof mac address, save current or restore or list.
# 
# pre-req: openssl
#
# Disclaimer: 
# This will obviously create lot of packet collitions/problems on the network and  
# create slowness, so you do choose to use this script, you are using at your own 
# risk and I am not liable for any loss or damage you have caused by using this script.
#
# Author:  Arul Selvan
# Version: Feb 4, 2017
# OS: macOS
#

my_mac_addr_file="$HOME/.my_mac_address"
iface="en0"
options_list="i:m:a:lsrh"
airport_bin="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
ap_ssid="AA-Inflight"
mac_to_spoof=""
operation=0 # [1=spoof, 2=save, 3=restore, 4=list]

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

change_mac() {
  local mac_address=$1
  ifconfig $iface down
  sleep 1
  ifconfig $iface ether $mac_address
  if [ $? -ne 0 ] ; then
    echo "[ERROR] changing mac to $mac_address failed. Try again."
  else
    echo "[INFO] successfully changed mac to $mac_address"
  fi
}

save_mac() {
  echo "[INFO] saving my mac address ..."
  if [ ! -f $my_mac_addr_file ] ; then
    echo "[WARN] no previously saved mac file ($my_mac_addr_file) found!"
    echo "[WARN] saving current mac address as saved mac address ..."
    my_mac=`ifconfig $iface|grep ether|awk '{print $2;}'`
    echo $my_mac > $my_mac_addr_file
  else
    my_mac=`cat $my_mac_addr_file`
    echo "[INFO] my mac address $my_mac is saved for future restore."
  fi
}

restore_mac() {
  if [ ! -f $my_mac_addr_file ] ; then
    echo "[ERROR] no previously saved mac file ($my_mac_addr_file) found!"
    exit
  fi
  my_mac=`cat $my_mac_addr_file`
  echo "[INFO] restoring mac to $my_mac on interface '$iface' ..."
  change_mac $my_mac
}

spoof_mac() {
  if [ $mac_to_spoof = "random" ] ; then
    echo "[INFO] generating a randmom mac ..."
    mac_to_spoof=`openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//"`
  fi
  echo "[INFO] spoofing your mac as '$mac_to_spoof' on interface '$iface'"
  change_mac $mac_to_spoof
}

show_mac() {
  my_mac=`ifconfig $iface|grep ether|awk '{print $2;}'`
  echo "[INFO] your current mac address on interface $iface is: $my_mac"
}

usage() {
  echo "Usage: $0 [options]"
  echo "  -i <interface> [default: $iface]"
  echo "  -m <mac_address_to_spoof> [mac address to spoof or \"random\" to generate one]"
  echo "  -s [saves current mac address]"
  echo "  -r [restores previously saved mac address]"
  echo "  -l [shows the currently used mac address]"
  echo "  -a [access point to reconnect. default: $ap_ssid]"
  exit
}

#  --- main entry ---
# parse commandline
while getopts "$options_list" opt; do
  case $opt in
    i)
      iface=$OPTARG
      ;;
    a)
      ap_ssid=$OPTARG
      ;;
    m)
      operation=1
      mac_to_spoof=$OPTARG
      ;;
    s)
      operation=2
      ;;
    r)
      operation=3
      ;;
    l)
      operation=4
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

check_root

# execute the request
case $operation in 
  1)
    # save first before spoofing so we can restore later.
    save_mac
    spoof_mac 
    ;;
  2)
    save_mac
    ;;
  3)
    restore_mac
    ;;
  4)
    show_mac
    ;;
  *)
    usage
    ;;
esac
