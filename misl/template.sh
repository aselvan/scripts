#!/bin/bash
#
# template.sh --- handy generic template to create new script
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=23.03.17
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
  cat << EOF

  Usage: $my_name [options]
     -v     ---> verbose mode prints info messages, otherwise just errors are printed
     -h     ---> print usage/help

  example: $my_name -h
  
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
  write_log "[STAT]" "starting at `date +'%m/%d/%y %r'` ..."
}

init_osenv() {
  if [ $os_name = "Darwin" ] ; then
    write_log "[STAT]" "MacOS environment"
  else
    write_log "[STAT]" "Other environment (Linux)"
  fi
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit
  fi
}

confirm_action() {
  local msg=$1
  echo $msg
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    return
  else
    write_log "[STAT]" "Cancelled executing $my_name!"
    exit 1
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

path_separate() {
  local path=$1
  local base_part=${path##*/}
  local name_part=${base_part%.*}
  local ext=${base_part##*.}

  echo "Base: $base_part"
  echo "Name: $name_part"
  echo "Ext:  $ext"
}

# ----------  main --------------
init_log
init_osenv
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

confirm_action "About to make a change..."
check_connectivity
if [ $? -eq 0 ] ; then
  write_log "[INFO]" "we have connectivity!"
else
  write_log "[WARN]" "We don't have network connectivity!"
fi

path_separate "/var/log/apache2/access.log"

