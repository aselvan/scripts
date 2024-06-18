#!/usr/bin/env bash
#
# functions.sh --- This script is meant to be included in main script for reusable functions.
#
#
# Author:  Arul Selvan
# Created: Nov 14, 2023
#
# Version History:
#   Nov 14, 2023 --- Original version
#   May 19, 2024 --- Added version_le, version_ge functions
#

# os and other vars
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
current_timestamp=`date +%s`

# calculate the elapsed time (shell automatically increments the var SECONDS magically)
SECONDS=0

# email variables
email_status=0
email_address=""
email_subject_success="$my_version on $host_name: SUCCESS"
email_subject_failed="$my_version on $host_name: FAILED"

# for unit converstion functions below
declare -A unit_table=(
    ["volt_to_millivolt"]="1000"
    ["millivolt_to_volt"]="0.001"
    ["celsius_to_fahrenheit"]=$(echo "scale=2; 9/5" | bc)
    ["fahrenheit_to_celsius"]=$(echo "scale=2; 5/9" | bc)
)

# -------------------- disk manipulation (linux only) --------------------
# when dd out image to a target disk of different size, we need to fix size mismatch
# GPT PMBR size mismatch
fix_gpt_mismatch() {
  local dev=$1
  if [ -z "$dev" ] ; then
    log.error "  Missing device!"
    return
  fi
  
  # ensure we are on linux platform and root
  check_linux
  check_root

  # Check if fdisk supports writing GPT table
  if ! fdisk -l $dev 2>&1 | grep -q -i "GPT"; then
    log.error "  Missing GPT string on $dev"
    return
  else
    log.debug "  Disk $dev might contain GPT mismatch, running fdisk"
  fi
  
  # Fix GPT PMBR size mismatch with fdisk (non-interactive)
fdisk $dev 2>&1 >/dev/null << EOF
w
EOF
  # Check exit code of fdisk
  if [[ $? -ne 0 ]]; then
    log.warn "  Failed to fix GPT PMBR size mismatch on $dev"
    return
  fi
  log.debug "  GPT PMBR size mismatch fixed on $dev"
}

# unmount all partitions on the device specified if they are already mounted
unmount_all_partitions() {
  local dev=$1

  # ensure we are on linux platform and root
  check_linux
  check_root
  
  partition_list=`lsblk $dev -o NAME -l|grep -e "[0-9]"`
  for p in $partition_list ; do
    # check if it is mounted before attempting to unmount
    grep $p /proc/mounts 2>&1 >/dev/null
    if [ $? -eq 0 ] ; then
      # it is mounted, unmount
      log.debug "  Dev /dev/$p is mounted state, unmounting it..."
      umount /dev/$p
    fi
  done
}


# --- ntfs partition extend/fix (linux only)
# WARNING: This will find the last partition and will extend it to the end of the physical drive
extend_ntfs_partition() {
  local dev=$1
  if [ -z "$dev" ] ; then
    log.error "  Missing device/partition!"
    return
  fi

  # ensure we are on linux platform and root and tools needed
  check_linux
  check_root
  check_installed ntfsresize noexit

  # find last partition
  local pnum=$(parted -s $dev print | awk '$1 ~ /^[0-9]+$/ { last = $1 } END { print last }')
  if [ -z "$pnum" ]; then
    log.error "  Unable to find the last partition!"
    return
  fi
  log.debug "  Last partition of $dev is: $pnum"

  # Resize the partition to the end of the disk
  log.stat "  Resisizing disk partion ..."
  parted -s $dev resizepart $pnum 100% >> $logger_file 2>&1
  if [ $? -ne 0 ] ; then
    log.error "  Error while resizing partition: ${dev}${pnum}"
    return
  fi

  # Check and repair NTFS filesystem
  log.stat "  Check/repair NTFS filesystem... (might take a few minutes)"
  ntfsfix ${dev}${pnum} >> $logger_file 2>&1
  if [ $? -ne 0 ] ; then
    log.error "  Error running ntfsfix on ${dev}${pnum}"
    return
  fi
  
  # scan for the ntfs file system
  log.stat "  Scanning NTFS file system ${dev}${pnum}"
  ntfsresize -i -f ${dev}${pnum} >> $logger_file 2>&1
  if [ $? -ne 0 ] ; then
    log.error "  Error while scanning for NTFS file system on ${dev}${pnum}"
    return
  fi

  # do a dry run and if it is successful, do the actual NTFS resize
  log.stat "  Dry run for NTFS file system resize operation on ${dev}${pnum}"  
  ntfsresize -f -f --no-action $dev$pnum >> $logger_file 2>&1
  if [ $? -eq 0 ] ; then
    log.stat "  Actual NTFS file system resize operation on ${dev}${pnum}"  
    ntfsresize -f -f ${dev}${pnum} >> $logger_file 2>&1
    if [ $? -ne 0 ] ; then
      log.error "  Resize NTFS filesystem on ${dev}${pnum} failed!"
    fi
  else
    log.error "  Dry run to resize NTFS filesystem on ${dev}${pnum} failed!"
    return
  fi
}


# --- file utils ---

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

#--- user related utilities ---
check_root() {
  if [ `id -u` -ne 0 ] ; then
    log.error "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit 1
  fi
}

check_linux() {
  if [ $os_name == "Linux" ] ; then
    return
  fi
  log.error "This is Linux only function ... exiting."
  exit 1
}

get_current_user() {
  # correctly return user if elevated run
  echo `who -m | awk '{print $1;}'`
}

check_installed() {
  local app=$1
  local noexit=$2
  if [ ! `which $app` ]; then
    if [ ! -z "$noexit" ] ; then
      log.warin "required binary \"$app\" is missing, skiping the task and continuing ..."
      return
    else
      log.error "required binary \"$app\" is missing, install it and try again, exiting."
      exit 2
    fi
  fi
}

#--- mail utilities ---
# Function takes 2 arguments email status, file data to email. If none
# provided the global variable $email_status & $logger_file used.
#
# NOTE: uses global variables above (see variables email_XXXX) that caller need 
# to set before calling this function. It also uses logger_file from logger.sh
# 
send_mail() {
  local status="$1"
  local data_file="$2"

  if [ -z $email_address ] ; then
    log.warn "Required email address is missing, skipping email ..."
    return;
  fi

  if [ -z "$status" ] ; then
    status=$email_status
  fi
  if [ -z "$data_file" ] ; then
    data_file=$logger_file
  fi

  if [ $status -ne 0 ] ; then
    log.debug "Sending failure mail ..."
    # strip any ansi chars
    strip_ansi_codes $data_file
    /bin/cat $data_file | /usr/bin/mail -s "$email_subject_failed" $email_address
  else
    log.debug "Sending success mail ..."
    # strip any ansi chars
    strip_ansi_codes $data_file
    /bin/cat $data_file | /usr/bin/mail -s "$email_subject_success" $email_address
  fi
}

#--- conversion utilities ---
# Define separate functions for each conversion.
# usage:
#   v2mv=$(v2mv 3.2)
#   echo "Volt/mVolt: 3.2/$v2mv"

v2mv() {
    echo "$(bc <<< "scale=2; $1 * ${unit_table[volt_to_millivolt]}")"
}

mv2v() {
    echo "$(bc <<< "scale=2; $1 * ${unit_table[millivolt_to_volt]}")"
}

c2f() {
    echo "$(bc <<< "scale=2; $1 * ${unit_table[celsius_to_fahrenheit]} + 32")"
}

f2c() {
    echo "$(bc <<< "scale=2; ($1 - 32) * ${unit_table[fahrenheit_to_celsius]}")"
}

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

# compare versions (le or ge)
# usage: check if my_version is less than or equal to 3.1.0
#   if version_le "$my_version" "3.1.10" ; then
#   fi
version_le() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

# Function to compare versions (greater than or equal)
version_ge() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | tail -n1)" ]
}

# returns a string of elapsed time since start. Bash magically advances $SECONDS variable!
elapsed_time() {
  local duration=$SECONDS
  echo "$(($duration / (60*60))) hour(s), $(($duration / 60)) minute(s) and $(($duration % 60)) second(s)"
}

# check if the ip string passed is in the form x.x.x.x 
#
# usage:
#   validate_ip 192.168.1.1
#   if [ $? -ne 0 ]; then
#     log.error "invalid ip"
#   fi
validate_ip() {
  local ip=$1
  local IFS='.' # Internal Field Separator set to '.'

  # Read the IP address into an array
  read -ra ip_parts <<< "$ip"

  # Check if the IP has four parts
  if [[ ${#ip_parts[@]} -ne 4 ]]; then
    return 1
  fi

  # Check each part of the IP
  for part in "${ip_parts[@]}"; do
    # Check if the part is a number and between 0 and 255
    if ! [[ $part =~ ^[0-9]+$ ]] || [[ $part -lt 0 ]] || [[ $part -gt 255 ]]; then
      return 1
    fi
  done
  # valid ip
  return 0
}

# returns 1 for YES, 0 for NO
confirm_action() {
  local msg=$1
  log.error "$msg"
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

# convert seconds to date
seconds_to_date() {
  local seconds=$1
  if [ $os_name = "Darwin" ] ; then
    echo "`date -r $seconds +'%m/%d/%Y %H:%M:%S'`"
  else
    echo "`date -d@${seconds} +'%m/%d/%Y %H:%M:%S'`"
  fi
}

# convert seconds from now or raw seconds. If secondt arg is 1 it will 
# result in seconds calculated from from Jan 1, 1970, otherwise just seconds
convert_seconds() {
  local seconds=$1
  local from_now=$2

  if [ "$from_now" -eq 1 ] ; then
    seconds=$(($seconds + $current_timestamp))
  fi
  echo "$(seconds_to_date $seconds)"
}

# convert milliseconds from now or raw msec. If second arg is 1 it will 
# result in milliseconds calculated from from Jan 1, 1970.
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
