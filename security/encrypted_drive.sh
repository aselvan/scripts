#!/usr/bin/env bash
#
# encrypted_drive.sh
#
# summary: script to store/retrieve files to/from encrypted folder
# 
# This script mounts a encrypted drive at specified path and copy your files to the encrypted 
# drive, and unmounts it. Optionally with -l option, it simply does a directory listing of 
# the encrypted files as well as -m causes to stay mounted for a period of time. The script 
# will create two directories (encrypted, decrypted) on drive/path if they don't exist. 
# The 'encrypted' directory contains the encrpted files which you can backup to any backup 
# mediums (external drive, even cloud backup like google drive, dropbox etc safely) for safe 
# keeping. To access the encrupted data when needed, you can run this script with -m option 
# which mounts a 'decrypted' directory through the encfs driver to expose them as as normal 
# files inside that directory note: it automatically unmounts after 5 minutes but you can, 
# optionaly set a longer or shorter time with -i option. On MacOS, when the decrypted drive 
# is in mounted state, you will have a mounted drive icon on your desktop for conveniently 
# copying your files to the drive while it is in mounted state. On the first time use of this
# script on a specific drive/path, it will ask you to choose a passphrase to encrypt files, 
# make sure you remember that because you need that later when you want to access the 
# encrypted drive.
#
# Author:  Arul Selvan
# Version: Jun 23, 2018
#
# NOTE: For this script to work you need to have fuse and encfs installed.
#
# Instructions for installing encfs
#
#   MacOS (before Catalina): 
#     brew cask install osxfuse
#     brew install encfs
#
#   MacOS (after Catalina):
#     brew install macfuse
#     brew install gromgit/fuse/encfs-mac
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
# Version History:
#   Jun 23, 2018  --- Original version
#   Jan 21, 2020  --- Refactor to use logger and functions includes
#

# version format YY.MM.DD
version=24.01.21
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="c:d:i:lmuh"

#enc_drive="/Volumes/exfat64g2"
enc_drive="/Users/arul/data/personal/keys/encfs"
option=0
file_to_copy=""
mounted=0
idle_minutes=15

usage() {
  cat <<EOF
$my_name - $my_title

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
    log.stat "$enc_drive/decrypted is mounted already!"
    mounted=1
  else
    log.stat "$enc_drive/decrypted is not mounted, attempting to mount."
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
    log.error "Error: failed to mount $enc_drive path!"
    exit
  fi
  mounted=1
  log.stat "Mounted $enc_drive/decrypted successfully"
  log.stat "$enc_drive/decrypted will stay mounted for $idle_minutes minute(s) and will auto unmount."
}

copy() {
  do_mount
  log.stat "Copying $file_to_copy to $enc_drive/decrypted ..."  
  cp $file_to_copy $enc_drive/decrypted
}

list() {
  do_mount
  log.stat "-------------------------------------------------"
  log.stat "Contents of $enc_drive/encrypted ... "
  ls -lthR $enc_drive/decrypted
  log.stat "-------------------------------------------------"
}

do_unmount() {
  log.stat "mounting $enc_drive/decrypted ... "    
  umount $enc_drive/decrypted
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

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
  log.warn "No option provided!"
  usage
fi
