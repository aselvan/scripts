#/bin/sh
#
# spoof_mac.sh
#
# Description: 
#  Spoof mac address, save current or restore.
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
options_list="i:m:lsrh"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

restore_mac() {
  if [ ! -f $my_mac_addr_file ] ; then
    echo "[ERROR] no previously saved mac file ($my_mac_addr_file) found!"
    exit
  fi
  my_mac=`cat $my_mac_addr_file`
  echo "[INFO] restoring mac to $my_mac on interface '$iface' ..."
  ifconfig $iface ether $my_mac
  exit
}

save_mac() {
  echo "[INFO] saving my mac address ..."
  my_mac=`ifconfig $iface|grep ether|awk '{print $2;}'`
  echo $my_mac > $my_mac_addr_file
  exit
}

spoof_mac() {
  mac_to_spoof=$1
  if [ $mac_to_spoof = "random" ] ; then
    echo "[INFO] generating a randmom mac ..."
    mac_to_spoof=`openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//"`
  fi
  echo "[INFO] spoofing your mac as '$mac_to_spoof' on interface '$iface'"
  ifconfig $iface ether $mac_to_spoof
  exit
}

show_mac() {
  my_mac=`ifconfig $iface|grep ether|awk '{print $2;}'`
  echo "[INFO] your current mac address on interface $iface is: $my_mac"
  exit
}

usage() {
  echo "Usage: $0 [options]"
  echo "  -i <interface> [default: en0 note: needs to be first argument to choose another interface]"
  echo "  -m <mac_address_to_spoof> [mac address to spoof or \"random\" to generate one]"
  echo "  -s [saves current mac address]"
  echo "  -r [restores previously saved mac address]"
  echo "  -l [shows the currently used mac address]"
  exit
}

check_root

while getopts "$options_list" opt; do
  case $opt in
    i)
      iface=$OPTARG
      ;;
    m)
      spoof_mac $OPTARG
      ;;
    s)
      save_mac
      ;;
    r)
      restore_mac
      ;;
    l)
      show_mac
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

usage
