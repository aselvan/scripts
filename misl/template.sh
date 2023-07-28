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

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="e:vh?"
verbose=0
failure=0
sample_env="${SAMPLE_ENV:-default_value}"

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

check_installed() {
  local app=$1
  if [ ! `which $app` ]; then
    write_log "[ERROR]" "required binary ('$app') is missing, install it and try again"
    exit 1
  fi
}

send_mail() {
  if [ -z $email_address ] ; then
    return;
  fi

  write_log "[INFO]" "Sending mail ..."
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
    write_log "[STAT]" "Confirm action is: YES"
    return
  else
    write_log "[STAT]" "Confirm action is: NO"
    return
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

msec_to_date() {
  local msec=$1
  human_readable_date=$(date -r $(( ($msec + 500) / 1000 )) +"%m/%d/%Y %H:%M:%S")
  echo $human_readable_date
}

# ----------  main --------------
init_log
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

send_mail
confirm_action "About to make a change..."
check_connectivity
if [ $? -eq 0 ] ; then
  write_log "[INFO]" "we have connectivity!"
else
  write_log "[WARN]" "We don't have network connectivity!"
fi

path_separate "/var/log/apache2/access.log"
date_st=$(msec_to_date "1686709485000")
echo "Converted 1686709485000 to human readble date: $date_st"

