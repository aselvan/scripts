#!/bin/bash
#
# template.sh --- handy generic template to create new script
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=22.07.19
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="vh?"
verbose=0
sample_env="${SAMPLE_ENV:-default_value}"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -v     ---> verbose mode prints info messages, otherwise just errors are printed"
  echo "  -h     ---> print usage/help"
  echo ""
  echo "example: $my_name -h"
  echo ""
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
  write_log "[STAT]" "$my_version: starting at `date +'%m/%d/%y %r'` ..."
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit
  fi
}

check_connectivity() {
  # google dns for validating connectivity
  local gdns=8.8.8.8
  local ping_interval=10
  local ping_attempt=3

  for (( attempt=0; attempt<$ping_attempt; attempt++ )) {
    write_log "[INFO]" "checking for connectivity, attempt #$attempt ..."
    ping -t30 -c3 -q $gdns >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      return 0
    fi
    write_log "[INFO]" "sleeping for $ping_interval sec for another attempt"
    sleep $ping_interval
  }
  return 1
}

# ----------  main --------------
init_log
# parse commandline options
while getopts $options opt; do
  case $opt in
    v)
      verbose=1
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

check_connectivity
if [ $? -eq 0 ] ; then
  write_log "[INFO]" "we have connectivity!"
else
  write_log "[WARN]" "We don't have network connectivity!"
fi
