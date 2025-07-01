#!/usr/bin/env bash
################################################################################
# cleanup_cache.sh --- Wipe MacOS cache, logs & document revisions etc 
#
# This script empties logs & cache. Especially cache directory in macOS tend to 
# grow a lot depending on usage. I often find it to gobble up a gig or more after
# a few weeks or so usage, not sure how much it grows if you let it go, but I am 
# not gonna let it. It builds up the cache as you start using apps anyways.
#
# Author:  Arul Selvan
# Version: Jun 14, 2020
################################################################################
#
# Version History:
#   Jun 14, 2020 --- Original version
#   May 4,  2024 --- delete document revisions wasting space, optionally remove 
#                    spotlight index
#   Feb 20, 2025 --- Remove spotlight indexing on / when cleanup requested
#   Feb 22, 2025 --- Remove spotlight indexing on *all* volumes
#   Mar 18, 2025 --- Use effective_user in place of get_current_user
#   Jul 1,  2025 --- Now prints how much space is reclaimed, also dry run option
#################################################################################

# version format YY.MM.DD
version=25.07.01
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wipe macOS cache, logs, revision backup, spotlight etc."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline arguments
options_list="u:snihv"

current_user=""
user_list="" # empty for current user i.e. no sudo needed
do_system=0  # by default just do user level only
document_rev_path="/System/Volumes/Data/.DocumentRevisions-V100"
do_spotlight=0
spotlight_path="/System/Volumes/Data/.Spotlight-V100"
spotlight_volume="/System/Volumes/Data/Applications"
dry_run=0

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -u <list> ---> List of users to clean [default: only current users cache is cleaned]
  -s        ---> Enable cleaning system level cache/logs as well
  -n        ---> dry run, do not clean, just shows potential space savings
  -v        ---> enable verbose, otherwise just errors are printed
  -i        ---> Clear spotlight (useful if lot of apps installed/removed orphaning index files) 
  -h        ---> print usage/help

example(s): 
  $my_name 
  $my_name -u "user1 user2 user3" -s -i
  
EOF
  exit 0
}

clean_user() {
  local user=$1
  local user_home="/Users/$user"
  local cache_dir="${user_home}/Library/Caches"
  local log_dir="${user_home}/Library/Logs"
  
  # ensure the cache directory exists
  if [ ! -d $cache_dir ] ; then
    log.error "  The user '$user' does not have cache dir, possibly non-existent user? skipping..."
    return
  fi
  log.stat "  ${cache_dir}: reclaimed: $(space_used $cache_dir)"
  if [ $dry_run -eq 0 ] ; then
    rm -rf $cache_dir/*
  fi

 # ensure the cache directory exists
  if [ ! -d $log_dir ] ; then
    log.error "  The user '$user' does not have log dir, possibly non-existent user? skipping..."
    return
  fi
  log.stat "  ${log_dir}: reclaimed: $(space_used $log_dir)"
  if [ $dry_run -eq 0 ] ; then  
    rm -rf $log_dir/*
  fi
}

clean_system() {
  local cache_dir="/Library/Caches"
  local log_dir="/Library/Logs"
  
  log.stat "  ${cache_dir}: reclaimed: $(space_used $cache_dir)"
  if [ $dry_run -eq 0 ] ; then  
    rm -rf $cache_dir/* 2>/dev/null 
  fi

  log.stat "  ${log_dir}: reclaimed: $(space_used $log_dir)"
  if [ $dry_run -eq 0 ] ; then
    rm -rf $log_dir/* 2>/dev/null
  fi
}

clean_spotlight() {
  log.stat "cleaning spotlight indexes ..." $green 
  if [ $dry_run -eq 1 ] ; then
    log.stat "  ${spotlight_path}: $(space_used $spotlight_path)"
    return
  fi

  # check with user
  confirm_action "WARNING: Spotlight index will be removed"
  if [ $? -eq 0 ] ; then
    log.warn "skipping spotlight cleanup"
    return
  fi

  log.stat "  disabling spotlight indexing for all volumes & stores ..."
  mdutil -adE -i off  >> $my_logfile 2>&1
  
  log.stat "  ${spotlight_path}: reclaimed: $(space_used $spotlight_path)"
  rm -rf $spotlight_path
  log.stat "  enabling spotlight indexing on $spotlight_volume only ..."
  mdutil -i on $spotlight_volume >> $my_logfile 2>&1

  log.stat "Spotlight indexing will start now as background process."
  log.stat "NOTE: indexing *will* take long time to complete, just let them (mds_store & mdworker) run."
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup" 
  exit 1
fi
# init logs
log.init $my_logfile

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    u)
      user_list="$OPTARG"
      ;;
    s)
      do_system=1
      ;;
    i)
      do_spotlight=1
      ;;
    n)
      dry_run=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
   esac
done

# ensure root access
check_root

# if user list is not provided, user current user by default
if [ -z "$user_list" ] ; then
  user_list=$effective_user
fi

if [ $dry_run -eq 1 ] ; then
  log.warn "Dry Run mode: space will not be deleted"
fi

for user in $user_list ; do
  log.stat "cleaning cache, logs for user: $user ..." $green
  clean_user $user
done

# clean system level (only if requested)
if [ $do_system -eq 1 ] ; then
  log.stat "cleaning cache, logs at system level ..." $green
  clean_system

  # clean the document revisions. (note: this would remove the ability to restore previous versions (mostly preview app)
  log.stat "cleaning document versions at system level... (reboot at your convenience)" $green
  rm -rf $document_rev_path
fi

# clean spotlight (only if requested)
if [ $do_spotlight -eq 1 ] ; then
  clean_spotlight
fi

log.stat "Cleanup completed"
