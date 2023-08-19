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
green=32
red=31
blue=34

sigok="sigok.ippacket.stream"
sigfail="sigfail.ippacket.stream"
oktest=0
failtest=0
other_dns_server=""
doh_flag="+https"

# ensure path for cron runs (make sure usr/local/gin
export PATH="/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

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
  local color=$2  
  if [ -z $color ] ; then
    color=$blue
  fi
  echo -e "\e[0;${color}m$msg\e[0m" | tee -a $log_file 
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

dot_check() {
  # make query and save output (we need 2 pice of info)
  dig $sigok $other_dns_server > $dig_output 2>&1
  # read the DNS server contacted
  dns_server=$(cat $dig_output|awk '/;; SERVER: /{print $3}')
  log.stat "  DNS server: $dns_server"

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
    log.stat  "  DoT protocol: Pass" $green
  elif [ $oktest -eq 1 ] ; then
    log.warn "  DoT protocol: Maybe"
  else
    log.stat "  DoT protocol: Failed" $red
  fi
}

doh_check() {
  # make with +https flags (will fail if dig is old or dns server does not support)
  dig $doh_flag $sigok $other_dns_server > $dig_output 2>&1
  rc=$?
  case $rc in 
    0)
      flags_line=$(cat $dig_output|awk '/;; flags: / {print $0}')
      log.debug "OK test response: $flags_line"
      # check if sigok DNS query response contains 'ad' flag a.k.a "Authenticated Data"
      if [[ $flags_line = *"ad"* ]] ; then
      # doh supported
        log.stat "  DoH protocol: Pass" $green
      else
        # doh not supported
        log.warn "  DoH protocol: Failed"    
      fi
      ;;
    1)
      # likely the case where dig client doesnt know +https argument
      log.warn "  DoH protocol: Failed (possibly dig client is not latest, upgrade & try)"
      ;;
    9)
      # likely the case where the dns_server used does not support DoH
      log.warn "  DoH protocol: Failed (DNS server does not suppor DoH protocol)"
      ;;
  esac
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

# check for DoT support
dot_check

# check for DoH support
doh_check
