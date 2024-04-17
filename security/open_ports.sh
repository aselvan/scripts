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
options="lervh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

resolve_ip="-n"
list_option=0

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -l  ---> Show only ports listening [default: all]
  -e  ---> Show only ports with established connections [default: all]
  -r  ---> Resolve remote address to hostname [WARN: this will take a while]
  -v  ---> enable verbose, otherwise just errors are printed
  -h  ---> print usage/help

example: $my_name -e
example: $my_name -e -r
 
EOF
  exit 0
}

show_listen() {
  log.stat "\nLIST OF SERVICES"
  log.stat "================="
  printf "%-20s %-10s %-20s\n"  "Application" "User" "Listen"
  printf "%-20s %-10s %-20s\n"  "-----------" "----" "------"
  if [ $os_name = "Darwin" ] ; then
    lsof +c 0 $resolve_ip -i | grep LISTEN | sort -f -k 1,1 |awk '{ gsub("x20","",$1); printf "%-*s %-*s %-*s %-*s\n", 20,$1, 10,$3, 3,$8, 20,$9}' | tee -a $my_logfile
  else
    lsof +c 0 $resolve_ip -i | grep LISTEN | sort -f -k 1,1 |awk '{printf "%-*s %-*s %-*s %-*s\n", 20,$1, 10,$3, 3,$8, 20,$9}' | tee -a $my_logfile
  fi

}

show_established() {
  log.stat "\nLIST OF CONNECTIONS"
  log.stat "===================="
  printf "%-32s %-10s %-50s\n"  "Application" "User" "Established"
  printf "%-32s %-10s %-50s\n"  "-----------" "----" "-----------"
  if [ $os_name = "Darwin" ] ; then
    # maxOS adds weird \x20 for spaces that is impossible to get rid of so we are leaving '\' but striping x20
    lsof +c 0 $resolve_ip -i | grep EST | sort -f -k 1,1 | awk '{ gsub("x20","",$1); printf "%-*s %-*s %-*s %-*s\n", 32,$1, 10,$3, 3,$8, 20,$9}' | tee -a $my_logfile
  else
    lsof +c 0 $resolve_ip -i | grep EST | sort -f -k 1,1 | awk '{printf "%-*s %-*s %-*s %-*s\n", 32,$1, 10,$3, 3,$8, 20,$9}' | tee -a $my_logfile
  fi
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
    r)
      resolve_ip=""
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

