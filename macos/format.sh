#!/usr/bin/env bash
#
# format.sh --- wrapper script over diskutils to format disk on MacOS
#
# Author:  Arul Selvan
# Created: Oct 18, 2020
#
# Version History:
#   Oct 18, 2020 --- Original version
#   Nov 2,  2024 --- Changed to use standard includes and additional options

# version format YY.MM.DD
version=24.11.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Format wrapper using diskutil on macOS"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="d:f:n:lvh"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

fat32_char_limit=8
fs_types="JHFS+ HFS+ FAT32 ExFAT"
disk_list=`diskutil list |grep dev| awk -F'/| ' '{print $3;}' |tr '\n' ' '`
volume_name="MYDISK"
fs_type=""
disk=""
disk_location=""
disk_type=""
disk_size=""
disk_virtual=""

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -d <disk>        ---> disk to format [Available: '$disk_list']
  -f <file_system> ---> file system to format [Available: '$fs_types']
  -n <name>        ---> disk name [Default: '$volume_name'] Note: for FAT32 it must be <8 char and all caps
  -v               ---> enable verbose, otherwise just errors are printed
  -l               ---> List all the available disks and the type and exit
  -h               ---> print usage/help
  
EOF
  exit 0
}

list_available_disks() {
  log.stat "Available Disks:"
  for d in $disk_list ; do
    disk_name=`diskutil info $d|grep "Media Name"|awk '{print $5,$6,$7}'`
    disk_location=`diskutil info $d|grep "Device Location"|awk '{print $3}'`
    disk_type=`diskutil info $d|grep "Solid State"|awk '{print $3}'`
    disk_size=`diskutil info $d|grep "Disk Size"|awk '{print $3,$4}'`
    disk_virtual=`diskutil info $d|grep "Virtual"|awk '{print $2}'`

    log.stat "  Disk: $d ; Name: $disk_name ; Location: $disk_location ; SSD: $disk_type ; Size: $disk_size ; Virtual: $disk_virtual"
  done
}

check_disk() {
  if [ -z $disk ] ; then
    echo "[ERROR] required disk argument is missing!" | tee -a $log_file
    usage
  fi

  for d in $disk_list ; do
    if [ $disk = $d ] ; then
      if [[ $disk = "disk0" || $disk = "disk1" ]] ; then
        log.warn "Typicaly '$disk' is where MacOS sits, so make sure you are absolutely sure before proceeding!"
      fi
      return
    fi
  done
  log.error "disk ($disk) is not one of the availabe disks '$disk_list'" 
  usage
}


check_format() {
  if [ -z $fs_type ] ; then
    log.error "equired format argument is missing!"
    usage
  fi

  for fs in $fs_types ; do
    if [ $fs_type = $fs ] ; then
      if [ $fs_type = "FAT32" ] ; then
        # capitalize volume name fat32
        volume_name=`printf '%s' $volume_name | awk '{print toupper($0); }'`
        length=${#volume_name}
        if [ $length -gt $fat32_char_limit ] ; then
          log.error "for $fs_type format, the disk name must be <= $fat32_char_limit characters"
          exit 2
        fi
      fi
      return
    fi
  done
  log.error "format '$fs_type' is not one of the availabe formats [i.e. '$fs_types']"
  usage
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile
check_root

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
    l)
      list_available_disks
      exit 0
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
   esac
done

# validate required args
if [[ -z $fs_type || -z $disk ]] ; then
  log.error "missing required arguments!"
  usage
fi

# check and make sure format and disk are valid
check_format
check_disk

# do the format after confirmation
confirm_action "About to format disk '/dev/$disk'"
if [ $? -eq 1 ] ; then
  log.stat "Formating ---> Disk: /dev/$disk; FileSystem: $fs_type; Volume Name: $volume_name"
  # note: the MBR argument avoids EFI partition automatically done by diskutil
  #diskutil eraseDisk $fs_type $volume_name MBR /dev/$disk 2>&1 | tee -a $mylog_file
  diskutil eraseDisk -noEFI $fs_type $volume_name $disk 2>&1 | tee -a $mylog_file
else
  log.warn "disk format cancelled"
fi

#
# TODO: implement partition 
# --------------------------
# the following example makes 2 partition FAT32 and ExFAT. With ExFAT 3g and the remaining 'R' used for FAT32
# diskutil partitionDisk disk2 MBR FAT32 MYPART1 R ExFAT MyPartiion2 3G
