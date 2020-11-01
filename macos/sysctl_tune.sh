#/bin/bash
#
# sysctl_tune.sh --- wrapper script to experiment w/ network stack tuning
#
# First run some network performance test i.e. like running speedtest-cli
# or better yet use netperf to get baseline. Then run this script with -s 
# option to setup optimal value, and rerun your performance test to see if 
# there is any significant improvements, you can then add these settings 
# permanently by coping (or appending) the file sysctl.conf in this directory 
# to /etc/sysctl.conf and reboot.
#
# Reference/Credit: 
# https://rolande.wordpress.com/2020/04/16/performance-tuning-the-network-stack-on-macos-high-sierra-10-13-and-mojave-10-14/
#
# Author:  Arul Selvan
# Version: Oct 31, 2020
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="srlh"

# Note: the default values to reset are from MacOS Catalina 10.15.7
default_settings="kern.ipc.somaxconn=128 net.inet.tcp.blackhole=0 net.inet.tcp.mssdflt=512 net.inet.tcp.recvspace=131072 net.inet.tcp.sendspace=131072 net.inet.tcp.slowstart_flightsize=1 net.inet.tcp.win_scale_factor=3 net.inet.udp.blackhole=0"

optimized_settings="kern.ipc.somaxconn=1024 net.inet.tcp.blackhole=2 net.inet.tcp.mssdflt=1448 net.inet.tcp.recvspace=524288 net.inet.tcp.sendspace=524288 net.inet.tcp.slowstart_flightsize=20 net.inet.tcp.win_scale_factor=4 net.inet.udp.blackhole=1"

usage() {
  echo "Usage: $my_name [-l] [-s] [-r]"
  echo "  -l list current values"
  echo "  -s setup with optimized values"
  echo "  -r restore default values"
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting." | tee -a $log_file
    exit
  fi
}

sysctl_list() {
  echo "[INFO] listing current sysctl values ..." | tee -a $log_file
  for v in $optimized_settings ; do
    var=`echo $v|awk -F= '{print $1;}'`
    /usr/sbin/sysctl $var
  done
  exit
}

sysctl_optimize() {
  echo "[INFO] setting optimized sysctl values ..." | tee -a $log_file
  for v in $optimized_settings ; do
    /usr/sbin/sysctl -w $v
  done
  exit
}

sysctl_restore() {
  echo "[INFO] restoring optimized sysctl values ..." | tee -a $log_file
  for v in $default_settings ; do
    /usr/sbin/sysctl -w $v
  done
  exit
}

# -------------------------- main -----------------------------
check_root
echo "[INFO] $my_name starting..." > $log_file

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    l)
      sysctl_list
      ;;
    s)
      sysctl_optimize
      ;;
    r)
      sysctl_restore
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
