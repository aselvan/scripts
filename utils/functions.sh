#
# functions.sh --- This script is meant to be included in main script for reusable functions.
#
#
# Author:  Arul Selvan
# Created: Nov 14, 2023
#

# os and other vars
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
current_timestamp=`date +%s`

# calculate the elapsed time (shell automatically increments the var SECONDS magically)
SECONDS=0

# email variables
email_address=""
email_status=0
email_subject_success="$host_name: SUCCESS"
email_subject_failed="$host_name: FAILED"

#--- user related utilities ---
check_root() {
  if [ `id -u` -ne 0 ] ; then
    log.error "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit 1
  fi
}

get_current_user() {
  # correctly return user if elevated run
  echo `who -m | awk '{print $1;}'`
}

check_installed() {
  local app=$1
  if [ ! `which $app` ]; then
    log.error "required binary ('$app') is missing, install it and try again"
    exit 2
  fi
}

#--- mail utilities ---
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

#--- general utilities ---

# convert sec to msec
sec2msec() {
  local sec=$1
  echo $( echo "$sec*1000/1"|bc )
}

# convert bytes kbytes
byte2kb() {
  local byte=$1
  echo $( echo "scale=2; $byte/1024"|bc -l )
}

# convert bytes megabyte
byte2mb() {
  local byte=$1
  echo $( echo "scale=2; $byte/(1024*1024)" | bc -l )
}

# convert bytes gigabyte
byte2gb() {
  local byte=$1
  echo $( echo "scale=2; $byte/(1024*1024*1024)" | bc -l )
}

# ---  string functions ---
# check to see if the string1 contains string2. It can be used with if statement as shown below
# if string_contains "$string1" "$string2" ; then
#   echo "contains"
# else
#   echo "does not contain"
# fi
string_contains() {
  local string1="$1"
  local string2="$2"
  if [ -z "$string1" ] || [ -z "$string2" ] ; then
    return 1
  fi
  echo "$string1" | egrep "$string2" 2>&1 > /dev/null
  return $?
}

# returns a string of elapsed time since start. Bash magically advances $SECONDS variable!
elapsed_time() {
  local duration=$SECONDS
  echo "$(($duration / (60*60))) hour(s), $(($duration / 60)) minute(s) and $(($duration % 60)) second(s)"
}

# Strip ansi codes from input file (note: this creates a temp file)
strip_ansi_codes() {
  local in_file=$1
  local tmp_file=$(mktemp)
  if [ -z $in_file ] || [ ! -f $in_file ] ; then
    log.error "Input file '$in_file' does not exists!"
    return
  fi
  cat $in_file | sed 's/\x1b\[[0-9;]*m//g'  > $tmp_file
  mv $tmp_file $in_file
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

#--- network connectivity utilities ---
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

# --- path utillities ---
path_separate() {
  local path=$1
  local base_part=${path##*/}
  local name_part=${base_part%.*}
  local ext=${base_part##*.}

  echo "Base: $base_part"
  echo "Name: $name_part"
  echo "Ext:  $ext"
}

# --- timestamp utilities ---
seconds_to_date() {
  local seconds=$1
  if [ $os_name = "Darwin" ] ; then
    echo "`date -r $seconds +'%m/%d/%Y %H:%M:%S'`"
  else
    echo "`date -d@${seconds} +'%m/%d/%Y %H:%M:%S'`"
  fi
}

convert_seconds() {
  local seconds=$1
  local from_now=$2

  if [ "$from_now" -eq 1 ] ; then
    seconds=$(($seconds + $current_timestamp))
  fi
  echo "$(seconds_to_date $seconds)"
}

convert_mseconds() {
  local msec=$1
  local from_now=$2

  # convert to seconds
  local seconds=$(( ($msec + 500) / 1000 ))

  if [ "$from_now" -eq 1 ] ; then
    seconds=$(($seconds + $current_timestamp))
  fi
  echo "$(seconds_to_date $seconds)"
}
