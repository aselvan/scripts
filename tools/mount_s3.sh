#!/bin/bash
#
# mount_s3.sh --- simple wrapper to mount s3fs
#
#
# Author:  Arul Selvan
# Version: Apr 10, 2021
#
# PreReq: brew install s3fs (or) sudo apt install s3fs
# Source: https://github.com/s3fs-fuse/s3fs-fuse/blob/master/README.md
# 
# Steps:
# ------
# 1. Setup the keys for s3fs
#   echo ACCESS_KEY_ID:SECRET_ACCESS_KEY > ${HOME}/.passwd-s3fs
#   chmod 600 ${HOME}/.passwd-s3fs
# 2. mounting (fstab & manual)
#   2.1 Add entry to fstab to mount like any other FS as shown below
#     mybucket /mnt/s3 fuse.s3fs _netdev,allow_other,use_path_request_style,url=https://url.to.s3/ 0 0
#   2.2 simply run this script to manually mount
#
os_name=`uname -s`
my_name=`basename $0`
options="b:m:s:dh"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

missing_s3fs_msg="missing s3fs, install with 'brew install s3fs' (or) 'sudo apt install s3fs'"
bucket=""
secret_file="$HOME/.passwd-s3fs"
mount_point="/mnt/s3"
mount_options="-o umask=0022 -o mp_umask=0022"
debug_opt="-o dbglevel=info -f -o curldbg"
debug=""

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -b <bucket>      ==> s3 bucket to mount [required argument]
  -m <path>        ==> mount point [default: $mount_point]
  -s <secret_file> ==> secert file path [default: $HOME/.passwd-s3fs]
  -h               ==> help

  example: $my_name -b my_s3_bucket_name -m /media/s3

EOF
  exit 1
}

# ---------------- main entry --------------------
# commandline parse
while getopts $options opt; do
  case $opt in
    b)
      bucket=$OPTARG
      ;;
    m)
      mount_point=$OPTARG
      ;;
    s)
      secret_file=$OPTARG
      ;;
    d)
      debug=$debug_opt
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
# make sure we have at least bucket defined
if [[ -z $bucket || ! -f $secret_file ]] ; then
  echo "[ERROR] required args missing!"
  usage
fi

which s3fs 2>&1 >/dev/null
if [ $? -gt 0 ]  ; then
  echo "[ERROR] $missing_s3fs_msg ... "
  exit 2
fi

mkdir -p $mount_point || exit 3
echo "Mounting S3 bucket ($bucket) at $mount_point ..." | tee -a $log_file 
s3fs $bucket $mount_point -o passwd_file=$secret_file $mount_options $debug
