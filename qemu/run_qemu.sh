#!/bin/bash
#
# run_qemu.sh --- simple wrapper to run qemu on macOS (should work on Linux as well)
#
# Author:  Arul Selvan
# Version: Sep 4, 2020
#
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
qemu_bin="qemu-system-x86_64"
memory=4096
cores=2
snapshot="-snapshot"
machine=pc-q35-2.10
# net example to forward ports
#net="user,hostfwd=tcp:127.0.0.1:3389-:3389"
net="user"
image_path="$HOME/VirtualBoxVMs/qemu"
boot_image="$image_path/winblows.qcow2"
host_dir_arg=""
host_dir_path=""
cpu="IvyBridge"
vga=std
additional_args=""
options_list="m:c:i:a:d:wh"


usage() {
  echo "Usage: $my_name [-m <memory> -c <count> -i <image> -a '<args>' -d <hostdir> -w -h]"
  echo "  -m <memory> size in MB to reserve for qemu. default is 4096"
  echo "  -c <count> count of cpu core to reserve for qemu. default is 2"
  echo "  -i <image> image name from $image_path ex: -i linux"
  echo "  -a <args> any additional qemu args to pass directly to $qemu_bin" 
  echo "  -w enable writing to base image. default is snapshot mode"
  echo "  -d <hostdir> shared as a read/write disk on running VM  i.e. /dev/sda1|sdb1 in linux"
  echo "  -h usage/help"
  exit
}

#  ------------ main -----------------
# process args
echo "[INFO] `date`: starting $my_name ..." | tee $log_file
while getopts "$options_list" opt; do
  case $opt in
    m)
      memory=$OPTARG
      ;;
    c)
      cores=$OPTARG
      ;;
    i)
      boot_image="${OPTARG}"
      ;;
    a)
      additional_args="$OPTARG"
      ;;
    w)
      snapshot=""
      ;;
    d)
      host_dir_path=${OPTARG}
      #host_dir_arg="-drive file=fat:ro:${host_dir_path}/,format=raw,media=disk"
      host_dir_arg="-drive file=fat:rw:${host_dir_path}/,format=raw,media=disk"
      # host share is now read-write so disable snapshot for it to work
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

# ensure image exists
if [ ! -f $boot_image ]; then 
  echo "[ERROR] boot image ($boot_image) does not exist!"
  usage
fi

echo "[INFO] options: memory=$memory; cpu=$cores; snapshot=$snapshot additional_args=$additional_args ..."|tee -a $log_file
echo "[INFO] options: image=$boot_image ..." | tee -a $log_file

if [ ! -z $host_dir_path ] ; then
  echo "[INFO] host directory ($host_dir_path) is shared as read/write drive i.e. /dev/sdb1 (or sda1)" | tee -a $log_file
fi

#
# we can add usb devices as shown on a 'as needed' basis. The vendor/product ids are from
# lsusb with colon separated ex: 1050:0120 (is Yuibico). Adding following argument would 
# expose yubi key to guest VM
#
# -device usb-host,vendorid=0x1050,productid=0x0120 \

$qemu_bin \
  -usb -device usb-tablet \
  -device intel-hda -device hda-output \
  -rtc base=localtime,clock=host \
  -vga $vga \
  -smp $cores \
  -m $memory \
  -machine $machine \
  -accel hvf \
  -nic $net \
  -hda $boot_image $snapshot $additional_args $host_dir_arg >> $log_file 2>&1

if [ $? -ne 0 ] ; then
  echo "[ERROR] $qemu_bin failed... see log below" | tee -a $log_file
  cat $log_file
else
  echo "[INFO] $qemu_bin exited normally" | tee -a $log_file
fi
