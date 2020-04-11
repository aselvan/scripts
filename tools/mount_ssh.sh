#/bin/sh
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
user=`who -m | awk '{print $1;}'`
os_name=`uname -s`
mount_bin=sshfs
mount_option=""
umount_option=""
remote_path=""
mount_point="$HOME/sshfs_mnt"

usage() {
  echo "Usage: "
  echo "  $0 mount <remote_path> <mount_point>"
  echo "  $0 unmount <mount_point>"
  echo "  Examples: $0 mount user@host:/path /mnt/path (or) $0 ummount /mnt/path"
  exit
}

# setup stuff based on OS
setup_vars() {
  if [ $os_name = "Darwin" ]; then
    umount_bin=umount
    mount_option="-ovolname=$remote_path"
  else
    umount_bin=fusermount
    umount_option="-u"
  fi
}

mount() {
  remote_path=$1
  if [ -z $remote_path ] ; then
    usage
  fi
  if [ -z $2 ]; then
    echo "[INFO] local mount point not provided, creating default ($mount_point) directory"
    mkdir -p $mount_point
  else
    mount_point=$2
  fi

  setup_vars

  echo "[INFO] mounting $1 @ $mount_point"
  $mount_bin $1 $mount_point $mount_option
  status=$?
  if [ $status -ne 0 ] ; then
    echo "[ERROR] mount failed!, errorcode=$status"
  else
    echo "[INFO] successfully mounted $1 @ $mount_point"
  fi
}

unmount() {
  if [ -z $1 ] ; then
    usage
  fi
  
  setup_vars

  echo "[INFO] unmounting $1"
  $umount_bin $umount_option $1
  status=$?
  if [ $status -ne 0 ] ; then
    echo "[ERROR] unmount failed!, errorcode=$status"
  else
    echo "[INFO] successfully unmounted $1"
  fi
}


# check if required tools are available
if [ ! -x "$(which $mount_bin)" ] ; then
  echo "[ERROR] sshfs is not installed" 
  echo "Install w/ 'brew install sshfs' in MacOS or 'apt-get install sshfs' in Ubuntu"
  exit
fi

case $1 in
  mount|unmount) "$@"
  ;;
  *)
  usage
  ;;
esac

