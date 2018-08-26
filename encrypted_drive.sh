#!/bin/bash
#
# encrypted_drive.sh
#
# summary: script to store/retrieve files to/from encrypted folder
# 
# This script mounts a encrypted drive at specified path and copy your files to the  
# encrypted drive, and unmounts it. Optionally with -l option, it simply does a directory 
# listing of the encrypted files. The script will create two directories (encrypted, decrypted) 
# on drive/path if they don't exist. The 'encrypted' contains the encrpted files which 
# are mounted on 'decrypted' directory through the encfs driver to expose them as normal 
# files. On the first time use of this on a specific drive/path, it will ask you to choose
# a passphrase to encrypt files, make sure you remember that because you need that later
# when you want to access the encrypted drive.
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
enc_drive="/Volumes/FAT64G"
options_list="c:d:lmuh"
option=0
file_to_copy=""
mounted=0
idle_minutes=5

usage() {
  echo "Usage: $0 [-d /my/encrypted/partition] -c <secret_file> | -mul"
  echo "  -d  <drive_path>    use the path provided as root [note: must be the first option]"
  echo "  -c  <secret_file>   mount the encrypted directory, copy the file, and unmount it"
  echo "  -l  mount the encrypted directory, list content, and unmount it"
  echo "  -m  mount the encrypted directory and leave it mounted. "
  echo "      CAUTION: drive stays mounted for $idle_minutes minutes"
  echo "  -u  unmount the already mounted directory"
  echo "  -h  help" 
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
  echo "[INFO]: $enc_drive/decrypted will stay mounted for $idle_minutes minutes and will auto unmount."
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
  echo "[ERROR] No option provided!"
  usage
fi
