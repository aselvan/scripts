#!/bin/bash
#
# iso2bootable.sh --- makes a bootable USB disk from ISO file on macOS
#
# Most OS distros like ubuntu provide a full bootable ISO file from their download area.
#
#
# Author:  Arul Selvan
# Created: Aug 7, 2022
#

# version format YY.MM.DD
version=22.08.07
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="i:d:vh?"
verbose=0
sample_env="${SAMPLE_ENV:-default_value}"
usb_disk=""
iso_file=""
dd_opt="bs=8m status=progress"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -i     ---> the ISO file to create your bootable USB disk"
  echo "  -d     ---> your USB diskid to flash i.e. id as reported by 'diskutil list |egrep '^/dev'|grep external'"
  echo "  -v     ---> verbose mode prints info messages, otherwise just errors are printed"
  echo "  -h     ---> print usage/help"
  echo ""
  echo "example: $my_name -d2 -i ubuntu.iso"
  echo ""
  exit 0
}

write_log() {
  local msg_type=$1
  local msg=$2

  # log info type only when verbose flag is set
  if [ "$msg_type" == "[INFO]" ] && [ $verbose -eq 0 ] ; then
    return
  fi
  echo "$msg_type $msg" | tee -a $log_file
}

init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "[STAT]" "$my_version: starting at `date +'%m/%d/%y %r'` ..."
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit
  fi
}

confirm_action() {
  local msg=$1
  echo $msg
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    return
  else
    write_log "[STAT]" "Cancelled executing $my_name!"
    exit 1
  fi
}

init_log
# parse commandline options
while getopts $options opt; do
  case $opt in
    i)
      iso_file=$OPTARG
      ;;
    d)
      usb_disk=$OPTARG
      ;;
    v)
      verbose=1
      ;;
    h)
      usage
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z $iso_file ] || [ -z $usb_disk ] ; then
  usage
fi

# validate the disk
diskutil list |egrep '^/dev'|grep external |grep "/dev/disk$usb_disk" >>$log_file 2>&1
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "The diskid $usb_disk does not correspond to a valid device!, check and try again!"
  exit 2
fi

# validate ISO file
if [ ! -f $iso_file ] ; then
  write_log "[ERROR]" "The ISO file ($iso_file) does not exists!"
  exit 3
fi

# unmount the disk
check_root
diskutil unmountDisk /dev/disk$usb_disk >> $log_file 2>&1
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "unable to unmount diskid $usb_disk, check and try again!"
  exit 4
fi

# double check before proceeding futher
confirm_action "About to flash /dev/disk$usb_disk. WARNING: Incorrect diskid will do serious damage to your data."

# create the image
rm -f ${iso_file}_image.dmg
hdiutil convert $iso_file -format UDRW -o ${iso_file}_image
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "converting ISO to IMG failed!"
  exit 5
fi

# flash
write_log "[STAT]" "flashing image ${iso_file}_image.dmg to /dev/disk$usb_disk ..."
dd $dd_opt if="${iso_file}_image.dmg" of=/dev/disk$usb_disk
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "failed to flash the image to /dev/disk$usb_disk!"
  exit 6
fi

rm -f ${iso_file}_image.dmg
write_log "[STAT]" "flashed /dev/disk$usb_disk successfully."
