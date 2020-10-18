#/bin/bash
#
# format.sh --- wrapper script over diskutils to format disk on MacOS
#
# Author:  Arul Selvan
# Version: Oct 18, 2020
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="d:f:n:ha"

diskutil_bin="/usr/sbin/diskutil"
fat32_char_limit=8
fs_types="JHFS+ HFS+ FAT32 ExFAT"
disk_list=`$diskutil_bin list |grep dev| awk -F'/| ' '{print $3;}' |tr '\n' ' '`
volume_name="MYDISK"
fs_type=""
disk=""

usage() {
  echo "Usage: $my_name -d <disk> -f <file_system> [-n <volume_name>]"
  echo "  -d <disk>        --- disk to format i.e. one of: $disk_list "
  echo "  -f <file_system> --- file system to format to i.e. one of: $fs_types"
  echo "  -n <name>        --- disk name i.e. $volume_name note: for FAT32 it must be <8 char and all caps"
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting." | tee -a $log_file
    exit
  fi
}

check_disk() {
  if [ -z $disk ] ; then
    echo "[ERROR] required disk argument is missing!" | tee -a $log_file
    usage
  fi

  for d in $disk_list ; do
    if [ $disk = $d ] ; then
      if [[ $disk = "disk0" || $disk = "disk1" ]] ; then
        echo "[WARN] typicaly '$disk' is where MacOS sits, so make sure you are absolutely sure before proceeding!"| tee -a $log_file
      fi
      return
    fi
  done
  echo "[ERROR] disk ($disk) is not one of the availabe disks '$disk_list'" | tee -a $log_file
  usage
}


check_format() {
  if [ -z $fs_type ] ; then
    echo "[ERROR] required format argument is missing!" | tee -a $log_file
    usage
  fi

  for fs in $fs_types ; do
    if [ $fs_type = $fs ] ; then
      if [ $fs_type = "FAT32" ] ; then
        # capitalize volume name fat32
        volume_name=`printf '%s' $volume_name | awk '{print toupper($0); }'`
        length=${#volume_name}
        if [ $length -gt $fat32_char_limit ] ; then
          echo "[ERROR] for $fs_type format, the disk name must be <= $fat32_char_limit characters" |tee -a $log_file
          exit
        fi
      fi
      return
    fi
  done
  echo "[ERROR] format ($fs_type) is not one of the availabe formats "| tee -a $log_file
  usage
}

# -------------------------- main -----------------------------
check_root
echo "[INFO] $my_name starting..." > $log_file

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    d)
      disk=$OPTARG
      ;;
    f)
      fs_type=$OPTARG
      ;;
    n)
      volume_name=$OPTARG
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

# validate required args
if [[ -z $fs_type || -z $disk ]] ; then
  echo "[ERROR] missing required arguments!" | tee -a $log_file
  usage
fi

# check and make sure format and disk are valid
check_format
check_disk

# do the format after confirmation
echo "[INFO] about to format disk '/dev/$disk' with file system '$fs_type' with volume name '$volume_name' ..." | tee -a $log_file
read -p "Are you sure? (y/n) " -n 1 -r
echo 
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  echo "[INFO] formatting ..." | tee -a $log_file
  # note: the MBR argument avoids EFI partition automatically done by diskutil
  $diskutil_bin eraseDisk $fs_type $volume_name MBR /dev/$disk 2>&1 | tee -a $log_file
else
  echo "[INFO] disk format cancelled." | tee -a $log_file
fi

#
# TODO: implement partition 
# --------------------------
# the following example makes 2 partition FAT32 and ExFAT. With ExFAT 3g and the remaining 'R' used for FAT32
# diskutil partitionDisk disk2 MBR FAT32 MYPART1 R ExFAT MyPartiion2 3G
