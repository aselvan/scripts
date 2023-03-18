#!/bin/bash
#
# veracrypt.sh --- simple wrapper over veracrypt to mount/unmount encrypted volumes
#
# Note: If no password is provided, script will look for password in the environment 
# variable VERACRYPT_PASSWORD but -p <password> argument will override password. 
#
# PreReq: veracrypt software must be installed (https://www.veracrypt.fr/en/Downloads.html)
#
# Author:  Arul Selvan
# Created: Mar 18, 2023
#

# version format YY.MM.DD
version=23.03.18
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="c:p:lmuvh?"
verbose=1
password="${VERACRYPT_PASSWORD:-}"
# volume will be mounted at $mount_point/$container_file 
container_file=""
mount_point="/mnt/veracrypt"
veracrypt_bin="/usr/bin/veracrypt"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -m <mountpoint>     ---> verbose mode prints info messages, otherwise just errors are printed
     -c <container_file> ---> encrypted container file to mount as volume
     -p <password>       ---> mount password for the encrypted container
     -u <mountpoint>     ---> unmount the currently mounted volume
     -l                  ---> list all veracrypt volumes
     -v                  ---> verbose mode prints info messages, otherwise just errors are printed
     -h                  ---> print usage/help

  example: $my_name -m $mount_point -c $HOME/veracrypt.hc -p "password123"
  
EOF
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
  write_log "[STAT]" "$my_version"
  write_log "[STAT]" "starting at `date +'%m/%d/%y %r'` ..."
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit 1
  fi
}

init_osenv() {
  if [ $os_name = "Darwin" ] ; then
    mount_point="$HOME/mnt/veracrypt"
    veracrypt_bin="/Applications/VeraCrypt.app/Contents/MacOS/VeraCrypt"
  else
    check_root
  fi
}

umount_veracrypt() {
  write_log "[INFO]" "Unmounting $mount_point volume ..."
  $veracrypt_bin -t -d $mount_point
  if [ $? -eq 0 ] ; then
    write_log "[INFO]" "Successfully umounted volume at $mount_point"
    exit 0
  else
    write_log "[ERROR]" "Failed to mount container '$container_file'"
    exit 1
  fi
}

list_volumes() {
  write_log "[INFO]" "list of volumes mounted in this host below"
  $veracrypt_bin -t -l
  exit 0
}

# ----------  main --------------
init_log
init_osenv
# parse commandline options
while getopts $options opt; do
  case $opt in
    m)
      mount_point="$OPTARG"
      ;;
    u)
      mount_point="$OPTARG"      
      umount_veracrypt
      ;;
    l)
      list_volumes 
      ;;
    p)
      password="$OPTARG"
      ;;
    c)
      container_file="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# check for password
if [[ -z $password || -z $container_file ]] ; then
  write_log "[ERROR]" "required arguments missing! See the usage below"
  usage
fi

if [ ! -d $mount_point ] ; then
  write_log "[ERROR]" "mount point '$mount_point' does not exist"
  usage
fi

# mount the volume
write_log "[INFO]" "Mounting $container_file at mount point $mount_point ..."
$veracrypt_bin -t -k "" --pim=0 --protect-hidden=no --slot 1 --password "$password" --mount-options=timestamp --mount $container_file $mount_point
if [ $? -eq 0 ] ; then
  write_log "[INFO]" "Successfully mounted volume at $mount_point"
  exit 0
else
  write_log "[ERROR]" "Failed to mount container '$container_file'"
  exit 1
fi
