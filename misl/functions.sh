#
# functions.sh --- This script is meant to be included in main script for reusable functions.
#
#
# Author:  Arul Selvan
# Created: Nov 14, 2023
#

# os and other vars
os_name=`uname -s`
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`

# email variables
email_address=""
email_status=0
email_subject_success="$host_name: SUCCESS"
email_subject_failed="$host_name: FAILED"

# -- reusable functions ---
check_root() {
  if [ `id -u` -ne 0 ] ; then
    log.error "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit 1
  fi
}

check_installed() {
  local app=$1
  if [ ! `which $app` ]; then
    log.error "required binary ('$app') is missing, install it and try again"
    exit 2
  fi
}

send_mail() {
  if [ -z $email_address ] ; then
    log.warn "required email address is missing to sendmail, continueing w/ out email..."
    return;
  fi

  log.info "Sending mail ..."
  if [ $email_status -ne 0 ] ; then
    /bin/cat $log_file | /usr/bin/mail -s "$email_subject_failed" $email_address
  else
    /bin/cat $log_file | /usr/bin/mail -s "$email_subject_success" $email_address
  fi

}

# returns 1 for YES, 0 for NO
confirm_action() {
  local msg=$1
  echo $msg
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    log.debug "Confirm action is: YES"
    return 1
  else
    log.debug "Confirm action is: NO"
    return 0
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

