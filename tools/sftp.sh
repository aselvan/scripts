#!/bin/bash
#
# sftp.sh --- simple wrapper to non-interactively upload/download/delete files from sftp server using curl
#
#
# Author:  Arul Selvan
# Version: May 12, 2017
#
os_name=`uname -s`
my_name=`basename $0`
options="c:d:p:s:u:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

remote_path="/"
sftp_server="emft.realpage.com"
filename=""
user_passwd=""
# operation [1=uplod, 2=download, 3=delet]
operation=0

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -s <sftp_server> ==> sftp server [default: $sftp_server]
  -c <user:pass>   ==> credentials user:password to connect to sftp server
  -p <path>        ==> remote path if any [default: $remote_path]
  -u <filename>    ==> upload 'filename' to sftp server
  -d <filename>    ==> download 'filename' sftp server
  -r <filename>    ==> remove/delete 'filename' sftp server
  -h               ==> help

  example: $my_name -u myfile -s mysftpserver -p /root -u username:password

EOF
  exit 1
}

# ---------------- main entry --------------------
# commandline parse
while getopts $options opt; do
  case $opt in
    s)
      sftp_server=$OPTARG
      ;;
    c)
      user_passwd=$OPTARG
      ;;
    p)
      remote_path=$OPTARG
      ;;
    u)
      filename=$OPTARG
      operation=1
      ;;
    d)
      filename=$OPTARG
      operation=2
      ;;
    r)
      filename=$OPTARG
      operation=3
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
# check for required args
if [[ -z $user_passwd || -z $filename ]] ; then
  echo "[ERROR] required args missing!"
  usage
fi

case $operation in 
  1) 
    echo "[INFO] upload $filename to sftp://$sftp_server$remote_path/$filename ..." | tee -a $log_file
    curl -s --show-error -k -T $filename --user $user_passwd sftp://$sftp_server/$remote_path/ --ftp-create-dirs >> $log_file 2>&1
    ;;
  2)
    echo "[INFO] download $filename from sftp://$sftp_server$remote_path/$filename ..." | tee -a $log_file
    curl -s --show-error -k --user $user_passwd sftp://$sftp_server --ftp-create-dirs -o $filename >> $log_file 2>&1
    ;;
  3)
    echo "[INFO] delete $filename from sftp://$sftp_server$remote_path/$filename ..." | tee -a $log_file
    curl -s --show-error -k --user $user_passwd sftp://$sftp_server -Q "rm $remote_path/$filename" --ftp-create-dirs >> $log_file 2>&1
    ;;
  *)
    echo "[ERROR] unknown operation"
    usage
    ;;
esac

rc=$?
if [ $rc -ne 0 ] ; then
  echo "[ERROR] upload|download|delete failed, error code=$rc" | tee -a $log_file
else
  echo "[INFO] upload|download|delete successful" | tee -a $log_file
fi
