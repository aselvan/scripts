#!/bin/bash
#
# encrypted_drive.sh
#
# summary: script to store/retrieve files to/from encrypted folder
# 
# This script mounts a encrypted drive at specified path and copy your files to the  
# encrypted drive, and unmounts it. Optionally with -l option, it simply does a directory 
# listing of the encrypted files as well as -m causes to stay mounted for a period of time. 
# The script will create two directories (encrypted, decrypted) on drive/path if they don't 
# exist. The 'encrypted' directory contains the encrpted files which you can backup to any 
# backup mediums (external drive, even cloud backup like google drive, dropbox etc safely) 
# for safe keeping. To access the encrupted data when needed, you can run this script with 
# -m option which mounts a 'decrypted' directory through the encfs driver to expose them as 
# as normal files inside that directory note: it automatically unmounts after 5 minutes but you 
# can, optionaly set a longer or shorter time with -i option. On MacOS, when the decrypted drive
# is in mounted state, you will have a mounted drive icon on your desktop for conveniently 
# copying your files to the drive while it is in mounted state. On the first time use of this
# script on a specific drive/path, it will ask you to choose a passphrase to encrypt files, 
# make sure you remember that because you need that later when you want to access the encrypted drive.
#
# Author:  Arul Selvan
# Version: Jun 23, 2018
#
# NOTE: For this script to work you need to have fuse and encfs installed.
#
# Instructions for installing encfs
#
#   Mac: run the following 2 commands on mac terminal (assumed you have brew installed)
#     brew cask install osxfuse
#     brew install encfs
#   
#   Linux:
#     Ubuntu/Debian: apt-get install encfs
#     Redhat/CentOS: yum install encfs  
#     Other: refer to your distro manual
#
#   Windows:
#      Sorry, wipe that junk and install Linux or buy a Mac!
#
# NOTE: Change the default enc_drive below to your drive/path before using this script.
#
#enc_drive="/Volumes/exfat64g2"
enc_drive="/Users/arul/data/personal/keys/encfs"
options_list="c:d:i:lmuh"
option=0
file_to_copy=""
mounted=0
idle_minutes=15

usage() {
  cat <<EOF
  
Usage: encrypted_drive.sh [-d /my/encrypted/partition] -c <secret_file> | -muli
  -d  <drive_path>  use the path provided as root. 
      NOTE: this must be the first option
  -i  <minutes>  specify how long the mounted drive should stay mounted. 
      default: 5 minutes
  -c  <secret_file>  mount the encrypted directory, copy the file 
      to the encrypted folder, and finally unmounts
  -m  mount the encrypted directory and leave it mounted. 
      NOTE: this option keeps the drive mounted for $idle_minutes minute(s)
  -l  mount the encrypted directory, list content, and unmount it
  -u  unmount the already mounted directory
  -h  help
EOF
  exit 1
}

check_directories() {
  # ensure encrypted, decrypted directories exist on the enc_drive
  if [ ! -d  $enc_drive/decrypted ] ; then
    mkdir -p  $enc_drive/decrypted
  fi
  if [ ! -d  $enc_drive/encrypted ] ; then
    mkdir -p  $enc_drive/encrypted
  fi
}

check_mounted() {
  mount | grep $enc_drive/decrypted
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "[INFO] $enc_drive/decrypted is mounted already!"
    mounted=1
  else
    echo "[INFO] $enc_drive/decrypted is not mounted, attempting to mount."
    mounted=0
  fi
}

do_mount() {
  check_mounted
  if [ $mounted -eq 1 ]; then
    return
  fi

  check_directories
  
  encfs --idle=$idle_minutes $enc_drive/encrypted $enc_drive/decrypted
  if [ $? -ne 0 ] ; then
    echo "[ERROR]: failed to mount $enc_drive path!"
    exit
  fi
  mounted=1
  echo "[INFO]: mounted $enc_drive/decrypted successfully"
  echo "[INFO]: $enc_drive/decrypted will stay mounted for $idle_minutes minute(s) and will auto unmount."
}

copy() {
  do_mount
  echo "[INFO]: copying $file_to_copy to $enc_drive/decrypted ..."  
  cp $file_to_copy $enc_drive/decrypted
}

list() {
  do_mount
  echo "-------------------------------------------------"
  echo "[INFO]: Contents of $enc_drive/encrypted ... "
  ls -lthR $enc_drive/decrypted
  echo "-------------------------------------------------"
}

do_unmount() {
  echo "[INFO]: unmounting $enc_drive/decrypted ... "    
  umount $enc_drive/decrypted
}

# -------------- main ---------------------

while getopts "$options_list" opt; do
  option=1
  case $opt in 
    d)
      enc_drive=$OPTARG
      ;;
    i)
      idle_minutes=$OPTARG
      ;;
    c)
      file_to_copy=$OPTARG
      copy
      do_unmount
      ;;
    l)
      list
      do_unmount
      ;;
    m)
      do_mount
      ;;
    u)
      do_unmount
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

if [ $option -eq 0 ]; then
  echo ""
  echo "[ERROR] No option provided!"
  usage
fi
