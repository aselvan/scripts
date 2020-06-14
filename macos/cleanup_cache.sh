#/bin/sh
#
# cleanup_cache.sh --- empty macOS cache, logs etc 
#
# This script empties logs & cache. Especially cache directory in macOS tend to 
# grow a lot depending usage. I often find it to gobble up a gig or more after
# a few weeks or so usage, not sure how much it grows if you let it go, but I am 
# not gonna let it. It builds up the cache as you start using apps anyways.
#
# Author:  Arul Selvan
# Version: Jun 14, 2020
#

# commandline arguments
options_list="usah"

my_name=`basename $0`
# works with user login or elevated run
user=`who -m | awk '{print $1;}'`


usage() {
  echo "Usage: $my_name [-u|-s|-a]"
  echo "   -u clean user level only"
  echo "   -s clean at systemlevel (requires sudo password)"
  echo "   -a clean user & systemlevel (requires sudo password)"
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run '$my_name' ... exiting."
    exit
  fi
}

clean_user() {
  cache_dir="$HOME/Library/Caches"
  log_dir="$HOME/Library/Logs"
  
  echo "[INFO] cleaning $cache_dir ..."
  rm -rf $cache_dir/*

  echo "[INFO] cleaning $log_dir ..."
  rm -rf $log_dir/*

}

clean_system() {
  cache_dir="/Library/Caches"
  log_dir="/Library/Logs"
  
  echo "[INFO] cleaning $cache_dir ..."
  rm -rf $cache_dir/*

  echo "[INFO] cleaning $log_dir ..."
  rm -rf $log_dir/*
}

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    u)
      echo "[INFO] cleaning cache, logs at user ($user) level..."
      clean_user
      exit 0
      ;;
    s)
      echo "[INFO] cleaning cache, logs at system level..."
      check_root
      clean_system
      exit 0
      ;;
    a)
      echo "[INFO] cleaning cache, logs at ALL levels ..."
      check_root
      clean_user
      clean_system
      exit 0
      ;;
    h)
      usage
      ;;
    *)
     usage
     ;;
   esac
done

usage
