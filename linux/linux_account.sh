#!/bin/sh
#
# Script to create/delete linux accounts.
#
# You can create users one by one or bulk with a csv file (must be encrupted with aes-256-cbc) that contains 
# user,password,comment,directory list on each line. note: dir list is ':' separated. For bulk delete, the 
# file expected to have just one user per line and is a plain text.
# 
# Author:  Arul Selvan
# Version: 11/1/2018
#

app_name=`basename $0`
app_path=`dirname $0`
log_file="/tmp/${app_name}_${USER}.out"
csv_file=
user_name=
user_password=
user_comment=
user_dirs=
operation="add"
user_home_path="/home"
user_shell="/sbin/nologin"
options_list="u:p:c:s:f:r:adh"


check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

usage(){
    echo "Usage: $app_name [-a|-d] -f <csv_file>|<-u <user_name> -p <password_in_plain> -c <comment>] [-s <shell>] [-h <home_path_prefix>] [-r <dirpath>"
    exit
}

delete_account() {
  if [ -z "$user_name" ] ; then
    return
  fi
  echo "[INFO] deleting user '${user_name}' ..." | tee -a $log_file
  userdel -rf $user_name
}

delete_account_from_file() {
  # csv file should have username, other comma separated entries are ignored.
  cat $csv_file | while IFS=',' read -r user_name junk ; do
    # trim args
    user_name=$(echo $user_name|xargs);
    delete_account
  done
}

create_account() {
  if [ -z $user_name -o -z $user_password ]; then
    return
  fi
  
  password=$(perl -e 'print crypt($ARGV[0], "password")' $user_password)
  home_dir="$user_home_path/$user_name"

  # create and setup directory structure
  echo "[INFO] Setting up new user '${user_name}' ..." | tee -a $log_file
  useradd -d $home_dir -c "$user_comment" -s $user_shell -p $password $user_name >>$log_file 2>&1
  rc=$?
  if [ $rc -ne 0 ] ; then
    echo "[ERROR] useradd failed, error=$rc, check $log_file for any additional errors..."| tee -a $log_file
    echo "Exiting ..."
    exit 
  fi

  # if we need to create any dir, do so here for each user
  if [ ! -z $user_dirs ] ; then
    # split the dirs first
    IFS=':' read -ra dirs <<< "$user_dirs"
    for d in "${dirs[@]}" ; do
      mkdir -p $home_dir/$d >>$log_file 2>&1
    done
    chown -R ${user_name}:${user_name} $home_dir >>$log_file 2>&1
  fi
}

create_account_from_file() {
  
  # csv file should have username, password, comment (must be encrypted w/ openssl aes-256-cbc & armored
  set -eo pipefail
  cat $csv_file |openssl aes-256-cbc -d -a| while IFS=',' read -r user_name user_password user_comment user_dirs junk ; do
    set -eo pipefail
    # trim args
    user_name=$(echo $user_name|xargs);
    user_password=$(echo $user_password|xargs);
    user_comment=$(echo $user_comment|xargs);
    user_dirs=$(echo $user_dirs|xargs);
    if [ -z $user_comment ] ; then
       user_comment=$user_name
    fi
    set +eo pipefail    
    create_account
  done
}

# ------------------- main ----------------------------------
check_root
echo "[INFO] $app_name starting ..." > $log_file

while getopts "$options_list" opt; do
  case $opt in 
    a)
      operation="add"
      ;;
    d)
      operation="delete"
      ;;
    u)
      user_name=$OPTARG
      ;;
    p)
      user_password=$OPTARG
      ;;
    c)
      user_comment=$OPTARG
      ;;
    r)
      user_dirs=$OPTARG
      ;;
    s)
      user_shell=$OPTARG
      ;;
    f)
      csv_file=$OPTARG
      ;;
    h)
      user_home_path=$OPTARG
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

# if no comment provided, use username as comment.
if [ -z $user_comment ] ; then
  user_comment=$user_name
fi

case $operation in  
  add) 
    # if csv file provided, read user, password and comment from it, otherwise use commandline args
    if [ ! -z $csv_file -a -f $csv_file ]; then
      create_account_from_file
    elif [ -z "$user_name" -o -z "$user_password" ]; then
      echo "[ERROR] one or more required args missing i.e. username or password" | tee -a $log_file
      usage
    fi
    create_account
    ;;
  delete)
    # if csv file provided, read user, password and comment from it, otherwise use commandline args
    if [ ! -z $csv_file -a -f $csv_file ]; then
      delete_account_from_file
    elif [ -z "$user_name" ]; then
      echo "[ERROR] one or more required args missing i.e. username" | tee -a $log_file
      usage
    fi
    delete_account
    ;;
  :)
    usage
    ;;
esac

echo "Done. Log file is at $log_file"
