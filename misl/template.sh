#!/usr/bin/env bash
#
# template.sh --- handy generic template to create new script
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=23.05.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)
sample_env="${SAMPLE_ENV:-default_value}"

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
options="e:vh?"
verbose=0
failure=0
green=32
red=31
blue=34

email_address=""
email_subject_success="$host_name: SUCCESS"
email_subject_failed="$host_name: FAILED"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -e <email>    ---> email address to send success/failure messages
     -v            ---> verbose mode prints info messages, otherwise just errors are printed
     -h            ---> print usage/help

  example: $my_name -h
  
EOF
  exit 0
}

# -- Log functions ---
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

init_osenv() {
  if [ $os_name = "Darwin" ] ; then
    log.info "MacOS environment"
  else
    log.info "Other environment (Linux)"
  fi
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    log.error "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit
  fi
}

check_installed() {
  local app=$1
  if [ ! `which $app` ]; then
    log.error "required binary ('$app') is missing, install it and try again"
    exit 1
  fi
}

send_mail() {
  if [ -z $email_address ] ; then
    return;
  fi

  log.info "Sending mail ..."
  if [ $failure -ne 0 ] ; then
    /bin/cat $log_file | /usr/bin/mail -s "$email_subject_failed" $email_address
  else
    /bin/cat $log_file | /usr/bin/mail -s "$email_subject_success" $email_address
  fi

}

confirm_action() {
  local msg=$1
  echo $msg
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    log.stat "Confirm action is: YES"
    return
  else
    log.stat "Confirm action is: NO"
    return
  fi
}

check_connectivity() {
  # google dns for validating connectivity
  local gdns=8.8.8.8
  local ping_interval=10
  local ping_attempt=3

  for (( attempt=0; attempt<$ping_attempt; attempt++ )) {
    log.info "checking for connectivity, attempt #$attempt ..."
    ping -t30 -c3 -q $gdns >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      return 0
    fi
    log.info "sleeping for $ping_interval sec for another attempt"
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

msec_to_date() {
  local msec=$1
  human_readable_date=$(date -r $(( ($msec + 500) / 1000 )) +"%m/%d/%Y %H:%M:%S")
  echo $human_readable_date
}

# ----------  main --------------
log.init
init_osenv
check_installed certigo

# parse commandline options
while getopts $options opt ; do
  case $opt in
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

log.stat "Log message in green" $green
log.debug "Debug message"

send_mail
confirm_action "About to make a change..."
check_connectivity
if [ $? -eq 0 ] ; then
  log.info "we have connectivity!"
else
  log.info "We don't have network connectivity!"
fi

path_separate "/var/log/apache2/access.log"
date_st=$(msec_to_date "1686709485000")
echo "Converted 1686709485000 to human readble date: $date_st"

