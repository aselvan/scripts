#!/bin/bash
#
#
# git_migrate.sh --- simple script to migrate/copy repo from one location to another.
#
# This script copies a git repo from one location to other including branch, tags history etc.
# Note: make sure you create an empty GIT repo at the dstination location first.
#
# Author:  Arul Selvan
# Version: Feb 21, 2022 
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
src_url=""
dst_url=""
repo_name=""
tmp_dir="/tmp"

# commandline options
options="s:d:r:t:h"

# print usage
function usage() {
  cat <<EOF
  
USAGE: $my_name -s <src_repo_url> -d <dst_repo_url> -r <repo_name> 
  
  -s <src_repo_url>  repo url of the src location
  -d <dst_repo_url>  repo url of the dst location [note: repo must exist/created]
  -r <repo_name>     name of a repository to copy from src to dst
  -t <tmp_dir>       name of a temporary directory to use [default: $tmp_dir]

  Examples:
  $my_name -s https://github.com/src-location -d https://github.com/dst-location -r myrepo.git
  
EOF
  exit
}

# ----------- main entry -----------
echo "[INFO] starting ..." | tee $log_file

# commandline parse
while getopts $options opt; do
  case $opt in
    s)
      src_url=$OPTARG
      ;;
    d)
      dst_url=$OPTARG
      ;;
    r)
      repo_name=$OPTARG
      ;;
    t)
      tmp_dir=$OPTARG
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

if [ -z $src_url ] || [ -z $dst_url ] || [ -z $repo_name ] ; then
  echo "[ERROR] missing one or more required arguments! See usage below" | tee -a $log_file
  usage
fi

echo "[INFO] migrate '$src_url/$repo_name' to '$dst_url/$repo_name' ..." | tee -a $log_file

git clone --bare $src_url/$repo_name $tmp_dir/$repo_name 2>&1 | tee -a $log_file
cd $tmp_dir/$repo_name
git push --mirror $dst_url/$repo_name 2>&1 | tee -a $log_file

echo "[INFO] repos migrated." | tee -a $log_file
