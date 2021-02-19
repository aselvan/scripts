#/bin/sh
#
# mount_smb.sh --- convenient wrapper to mount remote directory via smbfs
#
# Author:  Arul Selvan
# Version: Feb 19, 2021
#

# works with user login or elevated
user_name=`who -m | awk '{print $1;}'`
os_name=`uname -s`
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

options="r:l:u:dh"
local_path=""
remote_path=""
mount=1

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -r <remote_path> ==> remote host/path to mount. example: host.domain.tld/share
  -l <local_path>  ==> local path to mount the share. example: ~/mnt/smb-share
  -u <user>        ==> user name to use for authentication [default: $user_name]
  -d               ==> unmount the already mounted local path

  example: $my_name -r host.domain.tld/share -l ~/mnt/smb-share -u foobar

EOF
  exit
}

do_mount() {
  if [[ -z $remote_path || -z $local_path ]] ; then
    echo "[ERROR] missing mount args!" | tee -a $log_file
    usage
  fi

  echo "[INFO] mounting '$user_name@$remote_path' at  mount point '$local_path' ..." | tee -a $log_file
  /sbin/mount -t smbfs //$user_name@$remote_path $local_path
}

do_unmount() {
  if [ -z $local_path ]; then
    echo "[ERROR] missing unmount args!" | tee -a $log_file
    usage
  fi
  echo "[INFO] unmounting $local_path ..."| tee -a $log_file
  /sbin/umount $local_path
}

# ---------------- main entry --------------------
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
if [ $mount -eq 1 ] ; then
  do_mount
else
  do_unmount
fi
