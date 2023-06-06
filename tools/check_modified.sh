#!/bin/bash
#
# check_modified.sh --- Check if a path (file or dir) was modifed since last run.
#
# returns 0 if the file or dir is modified since last run otherwise non-zero
#
# Author:  Arul Selvan
# Created: Jun 5, 2023

# version format YY.MM.DD
version=23.06.05
my_name="`basename $0`"
my_version="`basename $0` v$version"
checksum_file_prefix=".sha256sum"
options="p:e:s:h?"
email_address=""
email_subject=""
path_to_check=""

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options] 
     -p <path>    ---> path (file or dir) to check for changes since last run
     -e <email>   ---> optional email address to mail if path is changed since last run
     -s <subject> ---> email subject
     -h           ---> print usage/help

  example: $my_name -h
  
EOF
  exit 1
}

send_mail() {
  local path=$1

  if [ -z $email_address ] ; then
    return;
  fi
  
  email_body="${my_version}: $path changed"
  if [ -z $email_subject ] ; then
    email_subject="${my_version}: $path changed"
  fi
  echo "$email_body" | mail -s "$email_subject" "$email_address"
}


check_path() {
  local path=$1
  local checksum_file=""
  
  if [ ! -e $path ] ; then
    echo "[ERROR] invalid/non-existent file or path: '$path'"
    exit 1
  fi

  # depending on file or path create checksum file
  if [ -f "$path" ] ; then
    local dir=$(dirname "$path")
    local file=$(basename "$path")
    checksum_file=${dir}/${checksum_file_prefix}-${file}
  elif [ -d "$path" ] ; then
    checksum_file=${path}/${checksum_file_prefix}
  else
    echo "[ERROR] path is not valid file or directory: '$path'"
    exit 2
  fi

  # If this was the first time this script was run i.e. no $checksum_file 
  # consider file as not changed since this there is nothing to compare
  if [ ! -e "$checksum_file" ] ; then
    # create file and exit
    ls -lR $path | sha256sum > $checksum_file
    exit 3
  fi
  
  # create a new checksum and compare with old
  cur_checksum_file="${checksum_file}.current"
  ls -lR $path | sha256sum > $cur_checksum_file
  diff -q $checksum_file $cur_checksum_file 2>&1 >/dev/null
  if [ $? -ne 0 ] ; then
    # changed, save new file, mail (if needed) and exit w/ 0 indicating change
    mv $cur_checksum_file $checksum_file
    send_mail $path
    exit 0
  else
    rm $cur_checksum_file
    exit 4
  fi
}

# ----------  main --------------
# parse commandline options
while getopts $options opt ; do
  case $opt in
    p)
      path_to_check="$OPTARG"
      ;;
    e)
      email_address="$OPTARG"
      ;;
    s)
      email_subject="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$path_to_check" ] ; then
  usage
fi

check_path $path_to_check

