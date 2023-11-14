#!/usr/bin/env bash
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
version=23.11.14
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper over touch command with extra functionality"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

options="l:r:t:e:dvh?"
the_list=""
ref_object=""
ref_file=""
timestamp=""
all_files=0
file_ext=""
touch_arg=""

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -l <list>      ---> List of space separted files/directories in quotes to set timestamp.
  -r <ref>       ---> file or a directory to read timestamp from, if not provided, current timestamp used.
  -t <timestamp> ---> timestamp YYYYMMDDHHMM the -r and -t cannot be used together
  -e <ext>       ---> only the files w/ <ext> are used to determine which latest file in dir should be used as ref
  -d             ---> causes all files in dir to be reset if an item in -l arg is dir.
  -v             ---> verbose mode prints info messages, otherwise just errors are printed.
  -h             ---> print usage/help

example: $my_name -l "/home/foo.txt /home/user/dir" -r /home/ -e jpg -v
  
EOF
  exit 0
}

get_timestamp_object() {
  if [ -z "$ref_object" ] ; then
    ref_file=""
  elif [ -f "$ref_object" ] ; then
    ref_file=$ref_object
  elif [ -d "$ref_object" ] ; then
    # make sure directory contains files
    if [[ $(find $ref_object -type f -maxdepth 1 2>/dev/null | wc -l) -eq 0 ]] ; then
      log.error "The reference argument directory ($ref_object) does not contain any file!"
      exit 1
    fi
    # find the latest file in that directory as ref file 
    ref_file=`ls -tap ${ref_object}/${file_ext} | grep -v /$ | head -1`
  else
    ref_file=""
  fi
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    l)
      the_list="$OPTARG"
      ;;
    r)
      ref_object="$OPTARG"
      ;;
    t)
      timestamp="$OPTARG"
      ;;
    e)
      file_ext="*.$OPTARG"
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
  log.warn "required argument is missing!"
  usage
fi

# validate if both -r and -t are given
if [ ! -z $ref_object ] && [ ! -z $timestamp ] ; then
  log.error "Cannot use both -r and -t together, see usage"
  usage
fi

# get the reference file
get_timestamp_object
if [ ! -z "$ref_file" ] ; then
  touch_arg="-r $ref_file"
else
  touch_arg="-t $timestamp"
fi


for obj in ${the_list} ;  do
  log.stat "reseting timestamp on '$obj' using timestamp of '$touch_arg' ..."
  
  # if obj is directory, touch on all files if requested in addition to the dir itself
  if [ -d "$obj" ] ; then
    if [ $all_files -eq 1 ] ; then
      touch $touch_arg $obj/*
      touch $touch_arg $obj
    else
      touch $touch_arg $obj
    fi
  elif [ -f "$obj" ] ; then
    touch $touch_arg $obj
  else
    log.warn "The item '$obj' is neither a file or directory, skipping..."
  fi
done
