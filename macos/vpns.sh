#!/bin/sh
#
# vpns.sh --- wrapper to start VPNSecrure on commandline. The reason for this script
#             is because VPNSeure sarts this app using osascript leaving it hanging
#             which suckingup more than 15% of CPU! WTF?
#
# Author:  Arul Selvan
# Version: Apr 12, 2020
#

log_file=/tmp/vpns.log
vpns_home="/etc/vpns1.2.4.1"
nwjs_bin="$vpns_home/openvpn.app/Contents/MacOS/nwjs"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting." | tee -a $log_file
    exit
  fi
}

check_root
echo "[INFO] VPNS commandline..."

#exev this on this script address space
exec $nwjs_bin > $log_file 2>&1 &
