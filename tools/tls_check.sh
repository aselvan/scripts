#!/bin/bash
#
# tls_check.sh --- wrapper script read and print TLS cert details of a webserver
#
# This is a simple wrapper to print basic things of a TLS connection to a webserver
# like cert issuer, expiry, tls protocol version/cipher using the certigo tool. The
# tool and jq tool must be installed for this script to work. By default, this wrapper
# just prints the basic things, but with -a option it becomes simply a passthrough 
# to certigo
#
# preReq:
#   brew install jq certigo (MacOS)
#   apt-get install jq (Linux) note: unfortunately there is no certigo on Linux :(
#
# Author:  Arul Selvan
# Created: Jul 23, 2023
#

# version format YY.MM.DD
version=23.07.23
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
json_file="/tmp/$(echo $my_name|cut -d. -f1).json"

options="s:avh?"
verbose=0
pass_through=0
server_name="selvansoft.com"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -s <server> ---> webserver to check for TLS cert details
     -a          ---> print everything from certigo output i.e. passthrough
     -v          ---> verbose mode prints info messages, otherwise just errors are printed
     -h          ---> print usage/help

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
  write_log "[STAT]" "Running from: $my_path"
  write_log "[STAT]" "Start time:   `date +'%m/%d/%y %r'` ..."
}

check_installed() {
  local app=$1
  if [ ! `which $app` ]; then
    write_log "[ERROR]" "required binary ('$app') is missing, install it and try again"
    exit 1
  fi
}

do_basic_details() {
  # capture the output to a file. Note we are intersted in first certificate i.e. -l 
  certigo connect -l -j $server_name|jq > $json_file

  # I am sure there is a better way to do this instead of parsing one 
  # item at a time like this ugly way, but I am lazy!
  echo "TLS Certificate & connection details ($server_name)"
  echo "Name:        `cat $json_file|jq -r '.certificates[0].subject.common_name|@text'`"
  echo "Issuer:      `cat $json_file|jq -r '.certificates[0].issuer.organization|@text'`"
  echo "Expiry:      `cat $json_file|jq -r '.certificates[0].not_after|@text'`"
  echo "DNS names:   `cat $json_file|jq -r '.certificates[0].dns_names|@text'`"
  echo "TLS version: `cat $json_file|jq -r '.tls_connection.version|@text'`"
  echo "TLS cipher:  `cat $json_file|jq -r '.tls_connection.cipher|@text'`"
}

do_pass_through() {
  certigo connect -j $server_name|jq 2>&1 | tee -a $log_file
}

# ----------  main --------------
init_log

# check for presence of tools needed for this wrapper
check_installed certigo
check_installed jq

# parse commandline options
while getopts $options opt ; do
  case $opt in
    v)
      verbose=1
      ;;
    a)
      pass_through=1
      ;;
    s)
      server_name="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ $pass_through -eq 0 ] ; then
  do_basic_details
else
  do_pass_through
fi
