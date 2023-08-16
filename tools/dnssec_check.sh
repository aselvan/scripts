#!/usr/bin/env bash
#
# dnssec_check.sh --- handy script to validate if your DNS queries going through
#                     dnssec protocol i.e. DoT (DNS over TLS)
#
# Author:  Arul Selvan
# Created: Aug 15, 2023
#

# version format YY.MM.DD
version=23.08.15
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
dig_output="/tmp/$(echo $my_name|cut -d. -f1).txt"
log_init=0
options="s:vh?"
verbose=0

sigok="sigok.ippacket.stream"
sigfail="sigfail.ippacket.stream"
oktest=0
failtest=0
other_dns_server=""


# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -s  ---> Check a specific DNS server for capability [default: use default DNS]
     -v  ---> verbose mode prints info messages, otherwise just errors are printed
     -h  ---> print usage/help

  example: $my_name 
  example: $my_name -s one.one.one.one
  
EOF
  exit 0
}

log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}

log.stat() {
  log.init
  local msg=$1
  echo -e "\e[0;34m$msg\e[0m" | tee -a $log_file 
}

log.warn() {
  log.init
  local msg=$1
  echo -e "\e[0;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[0;31m$msg\e[0m" | tee -a $log_file 
}

# ----------  main --------------
log.init

# parse commandline options
while getopts $options opt ; do
  case $opt in
    s)
      other_dns_server="@${OPTARG}"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# make query and save output (we need 2 pice of info)
dig $sigok $other_dns_server 2>&1 > $dig_output
# read the DNS server contacted
dns_server=$(cat $dig_output|awk '/;; SERVER: /{print $3}')
log.stat "  Checking DNS server: $dns_server"

flags_line=$(cat $dig_output|awk '/;; flags: / {print $0}')
log.debug "OK test response: $flags_line"
# check if sigok DNS query response contains 'ad' flag a.k.a "Authenticated Data"
if [[ $flags_line = *"ad"* ]] ; then
  oktest=1
fi

flags_line=$(dig $sigfail $other_dns_server |awk '/status: / {print $0}')
log.debug "Fail test response: $flags_line"
if [[ $flags_line = *"SERVFAIL"* ]] ; then
  failtest=1
fi

if [ $oktest -eq 1 ] && [ $failtest -eq 1 ] ; then
  log.stat "  Success: DNS server is DoT capable!"
else
  log.error "  Falied: DNS server is NOT DoT capable!"
fi

