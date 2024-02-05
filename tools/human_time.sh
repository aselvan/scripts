#!/usr/bin/env bash
#
# human_time.sh.sh --- script to convert UNIX seconds,mseconds to date/time stamp
#
#
# Author:  Arul Selvan
# Created: Dec 19, 2023
#

# version format YY.MM.DD
version=23.12.19
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Script to convert UNIX seconds,mseconds to date/time stamp"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:m:nvh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

mseconds=""
seconds=""
from_now="0"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <sec>  ---> seconds to convert to date/timestamp
  -m <msec> ---> milli seconds to convert to date/timestamp
  -n        ---> means "now" i.e. -s -m arguments assumed to be offset from now
  -v        ---> enable verbose, otherwise just errors are printed
  -h        ---> print usage/help

example: $my_name -s \`date +%s\` # prints time now in readable format
example: $my_name -n -s 42044   # the datetime will be 42044 seconds from now
  
EOF
  exit 0
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
    n)
      from_now=1
      ;;
    s)
      seconds="$OPTARG"
      ;;
    m)
      mseconds="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    e)
      email_address="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done


# validate args
if [ -z $seconds ] && [ -z $mseconds ] ; then
  log.error "Required argument is missing, see usage"
  usage
fi

if [ ! -z $seconds ] ; then
  log.stat "Timestamp $seconds (secs) translate to: $(convert_seconds $seconds $from_now)"
else
  log.stat "Timestamp $mseconds (msec) translate to: $(convert_mseconds $mseconds $from_now)"
fi
