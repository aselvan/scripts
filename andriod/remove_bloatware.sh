#!/bin/bash
#
# remove_bloatware.sh --- remove (actually just disable) bloatware using adb
#
# Even on Google Pixel which technically should not have any presense of bloatware 
# from bloat kings like samsung, verizon,att etc but I found some (see list) that I 
# have no clue how they got there and there is no uninstall that I can find. However, 
# the package manager (pm) from adb shell can be used to remove them for "current" 
# user i.e. user 0 thereby preventing this crap from running though not able to 
# fully remove them on a non-rooted phone.
#
# Note: in order for this script to work, you must have paired your phone w/ adb first. If 
# there are multiple devices paried, you need to specifiy device name using -s option.
#
# Author:  Arul Selvan
# Version: Mar 9, 2023 --- initial version
#
# ensure path for utilities
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.03.14
my_name=`basename $0`
my_version="$my_name v$version"
options_list="s:p:lau3h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
all_packages_file="/tmp/$(echo $my_name|cut -d. -f1)_allpackages.txt"
your_packages_file="/tmp/$(echo $my_name|cut -d. -f1)_yourpackages.txt"
device=""
device_count=0

# unwanted, unrequested bloatware that we never installed in the first place!
bloatware_list="com.customermobile.preload.vzw com.verizon.mips.services \
com.verizon.services com.samsung.slsi.telephony.oem.oemrilhookservice \
com.samsung.slsi.telephony.oemril com.vzw.apnlib com.att.myWireless \
com.att.tv com.verizon.obdm_permissions com.verizon.obdm com.att.callprotect"

usage() {
  cat << EOF
  Usage: $my_name -s <device> <[-l] [-r] [-a] [-3]>
    -s <device>  ---> device id of your phone paired with adb [must be first option]
    -l           ---> list all known bloatware
    -a           ---> list all packages in the phone
    -p <package> ---> check if <package> is installed.
    -3           ---> list all 3rd party packages only a.k.a apps you installed
    -u           ---> uninstall all bloatware
    -h help
EOF
  exit 0
}

connect_device() {
  # attempt to connect
  echo "[INFO] attempting to connect to the device ($device) ... "| tee -a $log_file
  adb connect $device 2>&1 | tee -a $log_file
}

check_device() {
  echo "[INFO] check if the device ($device) is connected  ... "| tee -a $log_file
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    if [[ $d == $device[:.]* ]]; then
      return
    fi
  done
  
  echo "[ERROR] the specified device ($device) does not exist or connected!" | tee -a $log_file
  exit 1
}

check_multiple_device() {
  # check if adb connected to multiple devices but we don't have -s option
  if [ $device_count -gt 1 ] && [ -z "$device" ] ; then
    echo "[ERROR] more than one device connected to adb, please specify device to use with -s option" | tee -a $log_file
    usage
    exit 2
  fi
}

list_bloatware() {
  check_multiple_device

  echo "[INFO] checking known list of bloatware..." | tee -a $log_file
  for bw in $bloatware_list ; do
    adb $device shell pm list packages |grep -q $bw
    if [ $? -eq 0 ] ; then
      path=$(adb $device shell pm path $bw)
      printf "\t$bw : Yes ; $path\n" | tee -a $log_file
    else
      printf "\t$bw : No\n" | tee -a $log_file
    fi
  done
  exit 0
}

list_all() {
  check_multiple_device

  echo "[INFO] creating a list of all pacakges ..." | tee -a $log_file
  adb $device shell pm list packages -e > $all_packages_file
  echo "[INFO] listed all pakages to file: $all_packages_file" | tee -a $log_file
  exit 0
}

check_package() {
  p=$1
  check_multiple_device

  echo "[INFO] checking presense of package '$p' ..." | tee -a $log_file
  adb $device shell pm list packages $p | grep -q $p
  if [ $? -eq 0 ] ; then
    echo "[INFO] package '$p': Found" | tee -a $log_file
  else
    echo "[INFO] package '$p': Not Found" | tee -a $log_file
  fi
  exit 0
}


list_3rdparty() {
  echo "[INFO] creating a list of all packages you installed ..." | tee -a $log_file
  adb $device shell pm list packages -3 > $your_packages_file
  echo "[INFO] listed all pakages to file: $your_packages_file" | tee -a $log_file
  exit 0
}

uninstall_bloatware() {
  uninstalled=0
  check_multiple_device
  echo "[INFO] uninstalling known list of bloatware ..." | tee -a $log_file
  for bw in $bloatware_list ; do
    adb $device shell pm list packages |grep -q $bw
    if [ $? -eq 0 ] ; then
      # found bloat, remove
      printf "\tRemoving $bw ..." | tee -a $log_file
      adb $device shell pm uninstall -k --user 0 $bw 2>&1 | tee -a $log_file
      uninstalled=1
    fi
  done
  if [ $uninstalled -eq 1 ] ; then
    echo "[INFO] uninstalled bloats, reboot phone to clear any currently running bloats!" | tee -a $log_file
  else
    echo "[INFO] no bloat found to uninstall!" | tee -a $log_file
  fi
  exit 0
}

# --------------- main ----------------------
echo "[INFO] $my_version" | tee $log_file

# first get device count
device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
# if device count is 0 just exit
if [ $device_count -eq 0 ] ; then
  echo "[ERROR] no devices are connected to adb, try pairing your phone." | tee -a $log_file
  exit 1
fi

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device=$OPTARG
      connect_device
      check_device
      device="-s $device"
      ;;
    l)
      list_bloatware
      ;;
    p)
      check_package $OPTARG
      ;;
    a)
      list_all
      ;;
    3)
      list_3rdparty
      ;;
    u)
      uninstall_bloatware
      ;;
    h)
      usage
      ;;
  esac
done

usage
exit 0

