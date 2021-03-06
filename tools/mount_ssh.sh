#!/bin/bash
#
# mount_ssh.sh --- convenient wrapper to mount remote directory via sshfs
#
# Pre req:
#  - You must have the following packages installed for this script to work
#  - Though not required, seting up ssh keybased login is ideal to avoid entering password on mount
#
# macOS: brew install sshfs
# Ubuntu: apt-get install sshfs
#
# Author:  Arul Selvan
# Version: Apr 11, 2020
#

# works with user login or elevated
user_name=`who -m | awk '{print $1;}'`
os_name=`uname -s`
mount_bin=sshfs
mount_option=""
umount_option=""
options="r:l:u:v:dh"
local_path=""
remote_path=""
mount=1
volume_name=""
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"


usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -r <remote_path> ==> remote host/path to mount. example: host.domain.tld:/share/path
  -l <local_path>  ==> local path to mount the share. example: ~/mnt/sshfs
  -u <user>        ==> user name to use for authentication [default: $user_name]
  -v <vol label>   ==> optional volume name to use [default: remote_path]
  -d               ==> unmount the already mounted local path

  example: $my_name -r host.domain.tld:/share/path -l ~/mnt/sshfs -u $user_name -d MyData

EOF
  exit
}

# setup stuff based on OS
setup_vars() {
  if [ $os_name = "Darwin" ]; then
    umount_bin=umount
    mount_option="-ovolname=$volume_name"
  else
    umount_bin=fusermount
    umount_option="-u"
  fi
}

do_mount() {
  if [[ -z $remote_path || -z $local_path ]] ; then
    echo "[ERROR] missing mount args!" | tee -a $log_file
    usage
  fi

  echo "[INFO] mounting '$user_name@$remote_path' at mount point '$local_path' ..." | tee -a $log_file
  $mount_bin $user_name@$remote_path $local_path $mount_option
  status=$?
  if [ $status -ne 0 ] ; then
    echo "[ERROR] mount failed!, errorcode=$status" | tee -a $log_file
  else
    echo "[INFO] successfully mounted '$user_name@$remote_path' at '$local_path'" | tee -a $log_file
  fi
}

do_unmount() {
  if [ -z $local_path ]; then
    echo "[ERROR] missing unmount args!" | tee -a $log_file
    usage
  fi

  echo "[INFO] unmounting $local_path ... " | tee -a $log_file
  $umount_bin $umount_option $local_path
  status=$?
  if [ $status -ne 0 ] ; then
    echo "[ERROR] unmount failed!, errorcode=$status" | tee -a $log_file
  else
    echo "[INFO] successfully unmounted $1" | tee -a $log_file
  fi
}

# ---------------- main entry --------------------

# check if required tools are available
if [ ! -x "$(which $mount_bin)" ] ; then
  echo "[ERROR] sshfs is not installed" 
  echo "Install w/ 'brew install sshfs' in MacOS or 'apt-get install sshfs' in Ubuntu"
  exit
fi

# commandline parse
while getopts $options opt; do
  case $opt in
    r)
      remote_path=$OPTARG
      ;;
    l)
      local_path=$OPTARG
      ;;
    u)
      user_name=$OPTARG
      ;;
    v)
      volume_name=$OPTARG
      ;;
    d)
      mount=0
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

echo "[INFO] $my_name starting ..." | tee $log_file
setup_vars

if [ $mount -eq 1 ] ; then
  if [ -z $volume_name ] ; then
    $volume_name="$remote_path"
  fi
  do_mount
else
  do_unmount
fi
