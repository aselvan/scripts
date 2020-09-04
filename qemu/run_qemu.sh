#!/bin/bash
#
# run_qemu.sh --- simple wrapper to run qemu on macOS (should work on Linux as well)
#
# Author:  Arul Selvan
# Version: Sep 4, 2020
#
memory=4096
cores=2
snapshot="-snapshot"
machine=pc-q35-2.10
# net example to forward ports
#net="user,hostfwd=tcp:127.0.0.1:3389-:3389"
net="user"
boot_image="/Users/arul/VirtualBoxVMs/qemu/W7-rp.qcow2"
cpu="IvyBridge"
vga=virtio
options_list="m:c:wh"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

# need to figure out sound
#sound=hda-duplexdd
#-audiodev spice,id=spice 
#-audiodev coreaudio,id=coreaudio

usage() {
  echo "Usage: $my_name [-m <memory> -c <count> -w -h]"
  echo "  -m <memory> size in MB to reserve for qemu. default is 4096"
  echo "  -c <count> count of cpu core to reserve for qemu. default is 2"
  echo "  -w enable writing to base image. default is snapshot mode"
  echo "  -h usage/help"
  exit
}

#  ------------ main -----------------
# process args
echo "[INFO] `date`: starting $my_name ..." > $log_file
while getopts "$options_list" opt; do
  case $opt in
    m)
      memory=$OPTARG
      ;;
    c)
      cores=$OPTARG
      ;;
    w)
      snapshot=""
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
   esac
done

echo "[INFO] options: memory=$memory; cpu=$cores; snapshot=$snapshot ..." >> $log_file

exec qemu-system-x86_64 \
  -rtc base=localtime,clock=host \
  -vga $vga \
  -smp $cores \
  -m $memory \
  -machine $machine \
  -accel hvf \
  -cpu $cpu \
  -nic $net \
  -hda $boot_image $snapshot >> $log_file 2>&1

