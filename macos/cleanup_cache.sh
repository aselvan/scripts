#!/usr/bin/env bash
#
# cleanup_cache.sh --- Wipe MacOS cache, logs etc 
#
# This script empties logs & cache. Especially cache directory in macOS tend to 
# grow a lot depending on usage. I often find it to gobble up a gig or more after
# a few weeks or so usage, not sure how much it grows if you let it go, but I am 
# not gonna let it. It builds up the cache as you start using apps anyways.
#
# Author:  Arul Selvan
# Version: Jun 14, 2020
#

# version format YY.MM.DD
version=23.12.13
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wipe macOS cache, logs etc"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline arguments
options_list="u:sahv"
current_user=""
user_list="" # empty for current user i.e. no sudo needed
do_system=0  # by default just do user level only

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -u <list>  ---> List of users to clean [default: only current users cache is cleaned]
  -s         ---> Enable cleaning system level cache/logs as well
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name 
example: $my_name -u "user1 user2 user3" -s
  
EOF
  exit 0
}


clean_user() {
  local user=$1
  local user_home="/Users/$user"
  cache_dir="${user_home}/Library/Caches"
  log_dir="${user_home}/Library/Logs"
  
  # ensure the cache directory exists
  if [ ! -d $cache_dir ] ; then
    log.error "  The user '$user' does not have cache dir, possibly non-existent user? skipping..."
    return
  fi
  log.stat "  cleaning at user level $cache_dir ..."
  rm -rf $cache_dir/*

 # ensure the cache directory exists
  if [ ! -d $log_dir ] ; then
    log.error "  The user '$user' does not have log dir, possibly non-existent user? skipping..."
    return
  fi
  log.stat "  cleaning at user level $log_dir ..."
  rm -rf $log_dir/*
}

clean_system() {
  cache_dir="/Library/Caches"
  log_dir="/Library/Logs"
  
  log.stat "  cleaning at system level $cache_dir ..."
  rm -rf $cache_dir/*

  log.stat "  cleaning at system level $log_dir ..."
  rm -rf $log_dir/*
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    u)
      user_list="$OPTARG"
      check_root
      ;;
    s)
      do_system=1
      check_root
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
   esac
done

# if user list is not provided, user current user by default
if [ -z "$user_list" ] ; then
  user_list=$(get_current_user)
fi

for user in $user_list ; do
  log.stat "cleaning cache, logs for user: $user ..." $green
  clean_user $user
done

# clean system if requested
if [ $do_system -eq 1 ] ; then
  log.stat "cleaning cache, logs at system level ..." $green
  clean_system
fi
