#!/bin/bash
#
# archive.sh --- script to archive files older than specific date to a permenant storage
#
# retun: exit w/ 0 on success non-zero on failure
#
# Author:  Arul Selvan
# Version: Dec 5, 2020
#

os_name=`uname -s`
my_name=`basename $0`
run_date=`date +'%F-%H%M'`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="e:s:d:n:th"

# source, dest default path 
#source_dir="/var/www/html/docserver/data"
#dest_dir="/archive001/www/www/docserver/data"
source_dir=""
dest_dir=""
log_dir=""
archive_list_file="/tmp/${run_date}_archive_list"
archive_failure_list_file="/tmp/${run_date}_archive_failure_list"
num_days=90
trial=0
global_error=0
error_count=0
too_many_errors=100
export PATH="/usr/bin:/sbin:/usr/local/bin:$PATH"

# email details
email_subject="${my_name}: "
email_address=""

usage() {
  echo "Usage: $my_name [options]"
  echo "  -s <path>   --- source path to archive"
  echo "  -d <path>   --- destination path to move files to"
  echo "  -n <days>   --- files older than 'days' will be moved to archive [default: $num_days]"
  echo "  -e <email>  --- email address to send alerts of any failure"
  echo "  -t          --- trial run to create list of files to be archieved but dont actually archive"
  exit 0
}

copy_logs() {
  cp $log_file $log_dir/${run_date}_$my_name.log
  if [ -f $archive_list_file ] ; then
    gzip --force $archive_list_file
    cp $archive_list_file.gz $log_dir/.
  fi
  if [ -f $archive_failure_list_file ] ; then
    gzip --force $archive_failure_list_file
    cp $archive_failure_list_file.gz $log_dir/.
  fi
}

quit() {
  error_code=$1
  echo "[INFO] error code = $error_code" | tee -a $log_file
  
  case $error_code in 
    0)
      email_subject="$email_subject SUCCESS"
      copy_logs
      ;;
    1|2)
      email_subject="$email_subject FAILED"
      ;;
    *)
      email_subject="$email_subject FAILED"
      copy_logs
      ;;
  esac

  # only send mail for failure if e-mail address provided
  if [[ ! -z $email_address && $error_code -ne 0 ]] ; then
    cat $log_file | mail -s "$email_subject" $email_address
  fi
  
  exit $error_code
}

create_archive_list() {
  echo "[INFO] creating archive list ..." | tee -a $log_file
  if [ ! -w $dest_dir ] ; then
    echo "[ERROR] destination path: $dest_dir does not exists or writable!" | tee -a $log_file
    quit 1
  fi

  log_dir="$dest_dir/log"
  mkdir -p $log_dir
  if [ $? -ne 0 ] ; then
    echo "[ERROR] unable to create log dir: $log_dir" |tee -a $log_file
    quit 2
  fi

  # ensure we can cd to source dir
  cd $source_dir >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] $source_dir does not exists!" |tee -a $log_file 
    quit 3
  fi

  find . -type f -mtime +$num_days | sed -e 's/^\.//g' > $archive_list_file
  if [ ! -s $archive_list_file ] ; then
    echo "[ERROR] no files found that are > $num_days days old!" | tee -a $log_file
    quit 4
  fi
}

trial_archive() {
  echo "[INFO] trial run ..." | tee -a $log_file
  create_archive_list
}

archive() {
  echo "[INFO] archive run ..." | tee -a $log_file
  create_archive_list
  touch $archive_failure_list_file
  file_count=0
  cd $source_dir
  while read fpath ; do
    if [ ! -f $source_dir/$fpath ] ; then
      echo "$source_dir/$fpath does not exists!, skiping..." >> $archive_failure_list_file
      global_error=5
      error_count=$((error_count + 1))      
      continue
    fi

    # make sure destination contains the path structure we try to move
    dpath=`dirname $dest_dir/$fpath`
    if [ ! -d $dpath ] ; then
      mkdir -p $dpath
    fi

    # now move the file
    mv -fv "$source_dir/$fpath" "$dest_dir/$fpath" >/dev/null 2>&1
    if [ $? -ne 0 ] ; then
      # move failed
      echo "mv $source_dir/$fpath $dest_dir/$fpath failed!, skiping ... " >> $archive_failure_list_file
      global_error=5
      error_count=$((error_count + 1))
      continue
    fi
    echo "Archiveing: $fpath"
    file_count=$((file_count + 1))

    # if the error count exceeded a threashold, just quit
    if [ $error_count -gt $too_many_errors ] ; then
      echo "[ERROR] Too many errors (error count $error_count > $too_many_errors), bailing out." | tee -a $log_file
      quit 6
    fi
  done < $archive_list_file

  echo "[INFO] archieved $file_count files to $dest_dir" | tee -a $log_file
}


# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    e)
      email_address=$OPTARG
      ;;
    s)
      source_dir=$OPTARG
      ;;
    d)
      dest_dir=$OPTARG
      ;;
    n)
      num_days=$OPTARG
      ;;
    t)
      trial=1
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

echo "[INFO] starting '$my_name $@'"  | tee $log_file
if [[ -z $source_dir || -z $dest_dir ]] ; then
  echo "[ERROR] required arguments source or destination path missing!" | tee -a $log_file
  usage
fi
echo "[INFO] source path: $source_dir" | tee -a $log_file
echo "[INFO] dest path: $dest_dir" | tee -a $log_file
echo "[INFO] archive older than: $num_days days" | tee -a $log_file

if [ $trial -eq 1 ] ; then
  trial_archive
else
  archive
fi

quit $global_error
