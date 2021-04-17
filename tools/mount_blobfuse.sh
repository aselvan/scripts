#!/bin/bash
#
# mount_blobfuse.sh --- simple wrapper to mount azure blobstorage as filesystem
#
#
# Author:  Arul Selvan
# Version: Apr 17, 2021
#
# PreReq: apt-get install blobfuse fuse
# Source: https://github.com/Azure/azure-storage-fuse
# 
# Steps:
# ------
# create a credential file to pass to the driver as shown below or set environment variables
# 
#   echo accountName myaccountname      >  $HOME/.passwd-azblob_storage
#   echo accountKey myaccountkey        >> $HOME/.passwd-azblob_storage
# (OR)
#   export AZURE_STORAGE_ACCOUNT=myaccountname
#   export AZURE_STORAGE_ACCESS_KEY=myaccountkey
#
os_name=`uname -s`
my_name=`basename $0`
options="c:m:s:t:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

missing_blobfuse_msg="missing blobfuse, install with 'apt-get install blobfuse fuse'"
container=""
config_file="$HOME/.passwd-azblob_storage"
mount_point="/mnt/azblob"
tmp_path="/mnt/tmp"
mount_options="-o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120"

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -c <containername>  ==> azure blob container name [required]
  -m <path>           ==> mount point [default: $mount_point]
  -s <connfig_file>   ==> secert file path [default: $HOME/.passwd-azblob_storage]
  -t <temp_path>      ==> temp path, a fast drive or a ram drive is better [default: $tmp_path]
  -h                  ==> help

  example: $my_name -c mycontainer -m /media/azure_blob

EOF
  exit 1
}

# ---------------- main entry --------------------
# commandline parse
while getopts $options opt; do
  case $opt in
    c)
      container=$OPTARG
      ;;
    m)
      mount_point=$OPTARG
      ;;
    t)
      tmp_path=$OPTARG
      ;;
    s)
      config_file=$OPTARG
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

if [ $os_name = "Darwin" ] ; then
  echo "[ERROR] sorry blobfuse filesystem driver is not supported under MacOS!"
  exit 1
fi

which blobfuse 2>&1 >/dev/null
if [ $? -gt 0 ]  ; then
  echo "[ERROR] $missing_s3fs_msg ... "
  exit 2
fi

echo "[INFO] $my_name starting ..." | tee $log_file 
# make sure we have at least bucket defined
if [ -z $container ] ; then
  echo "[ERROR] required args missing!"
  usage
fi

mkdir -p $mount_point || exit 3
mkdir -p $tmp_path || exit 4

echo "[INFO] Mounting azureblob container ($container) at $mount_point ..." | tee -a $log_file
if [ -f $config_file ] ; then
  echo "[INFO] Using connection/config ($config_file) for authentication..." | tee -a $log_file
  blobfuse $mount_point --tmp-path=$tmp_path --config-file=$config_file --container-name=$container $mount_options
  rc=$?
else
  if [[ -z $AZURE_STORAGE_ACCOUNT || -z $AZURE_STORAGE_ACCESS_KEY ]] ; then
    echo "[ERROR] authentication file or env variables missing!"
    usage
  fi
  blobfuse $mount_point --tmp-path=$tmp_path --container-name=$container $mount_options
  rc=$?
fi
if [ $rc -ne 0 ] ; then
  echo "[ERROR] mount failed! error=$rc " |tee -a $log_file
else
  echo "[INFO] Mounted ($container) at $mount_point ..." | tee -a $log_file
fi


