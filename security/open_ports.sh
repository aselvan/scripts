#!/usr/bin/env bash
#
# Simple wrapper script to list open ports (established & listen) and apps responsible.
#
# PreReq: lsof 
#
# Author: Arul Selvan
# Version History:
#   Apr 15,  2024 --- Original version
#

# version format YY.MM.DD
version=24.04.15
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="List open ports (established & listen) and apps responsible"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="levh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

list_option=0

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -l  ---> Show only ports listening [default: all]
  -e  ---> Show only ports with established connections [default: all]
  -v  ---> enable verbose, otherwise just errors are printed
  -h  ---> print usage/help

example: $my_name -e
 
EOF
  exit 0
}

show_listen() {
  log.stat "\nList of services Listening"
  printf "%-20s %-10s %-20s\n"  "Application" "User" "Listen"
  printf "%-20s %-10s %-20s\n"  "-----------" "----" "------"
  lsof +c 0 -n -i | grep LISTEN | sort -f -k 1,1 |awk '{printf "%-*s %-*s %-*s %-*s\n", 20,$1, 10,$3, 3,$8, 20,$9}' | tee -a $my_logfile
}

show_established() {
  log.stat "\nList of connection established"
  printf "%-40s %-10s %-50s\n"  "Application" "User" "Established"
  printf "%-40s %-10s %-50s\n"  "-----------" "----" "-----------"
  lsof +c 0 -n -i | grep EST | sort -f -k 1,1 | awk '{printf "%-*s %-*s %-*s %-*s\n", 40,$1, 10,$3, 3,$8, 20,$9}' | tee -a $my_logfile
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    l)
      list_option=1
      ;;
    e)
      list_option=2
      ;;
    v)
      list_option=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

case $list_option in 
  0)
    show_listen
    show_established
    ;;
  1)
    show_listen
    ;;
  2)
    show_established
    ;;
esac

