#!/bin/bash
#
# my_touch.sh --- handy wrapper over touch command with extra functionality
#   
#  This script changes the timestamp of files or direcctories provided using the
#  timestamp matching the provided reference (can be a file or a directory). In the
#  case where reference is file, its timestamp of the file is used, and if the 
#  reference is a directory, the latest file in the directory is used as reference.
#  Finally, of no reference is provided, current timestamp is assumed.
#
# Author:  Arul Selvan
# Created: Jun 21, 2023
#

# version format YY.MM.DD
version=23.06.21
my_name="`basename $0`"
my_version="`basename $0` v$version"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="l:r:dvh?"
my_path=$(cd $dir_name; pwd -P)
verbose=0
the_list=""
ref_object=""
ref_file=""
ref_arg=""
all_files=0

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -l <list>     ---> List of space separted files/directories in quotes to set timestamp.
     -r <file|dir> ---> file or a directory to read timestamp from, if not provided, current timestamp used.
     -d            ---> causes all files in dir to be reset if an item in <list> is dir.
     -v            ---> verbose mode prints info messages, otherwise just errors are printed.
     -h            ---> print usage/help

  example: $my_name -l "/home/foo.txt /home/user/dir" -r /home/bar.txt
  
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
  write_log "[STAT]" "Running from: $my_path"
  write_log "[STAT]" "Start time:   `date +'%m/%d/%y %r'`"
}

get_timestamp_object() {
  if [ -z "$ref_object" ] ; then
    ref_file=""
  elif [ -f "$ref_object" ] ; then
    ref_file=$ref_object
  elif [ -d "$ref_object" ] ; then
    # make sure directory contains files
    if [[ $(find $ref_object -type f -maxdepth 1 2>/dev/null | wc -l) -eq 0 ]] ; then
      write_log "[ERROR]" "The reference argument directory ($ref_object) does not contain any file!"
      exit 1
    fi
    # find the latest file in that directory as ref file
    ref_file="${ref_object}/`ls -tap ${ref_object} | grep -v /$ | head -1`"
  else
    echo ref_file=""
  fi
}

# ----------  main --------------
init_log
# parse commandline options
while getopts $options opt ; do
  case $opt in
    l)
      the_list="$OPTARG"
      ;;
    r)
      ref_object="$OPTARG"
      ;;
    d)
      all_files=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$the_list" ] ; then
  write_log "[WARN]" "required argument is missing!"
  usage
fi

# get the reference file
get_timestamp_object
if [ ! -z "$ref_file" ] ; then
  ref_arg="-r $ref_file"
fi


for obj in ${the_list} ;  do
  write_log "[INFO]" "reseting timestamp on '$obj' using timestamp of '$ref_file' ..."
  
  # if obj is directory, touch on all files if requested in addition to the dir itself
  if [ -d "$obj" ] ; then
    if [ $all_files -eq 1 ] ; then
      touch $ref_arg $obj/*
      touch $ref_arg $obj
    else
      touch $ref_arg $obj
    fi
  elif [ -f "$obj" ] ; then
    touch $ref_arg $obj
  else
    write_log "[WARN]" "The item '$obj' is neither a file or directory, skipping..."
  fi
done
