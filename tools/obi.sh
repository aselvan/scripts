#!/bin/bash
#
# obi.sh --- wrapper script to interact w/ OBi200 (or any OBi device)
#
#
# Author:  Arul Selvan
# Version: Dec 6, 2014 
#

os_name=`uname -s`
my_name=`basename $0`

options="rsah"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
obi_output="/tmp/obi_output.log"
audio_path="$HOME/obi-recordings"
obienv_file="$HOME/.obienv"
# default port
port=0

# TODO
# The following ID is needed to hangup the call so make sure this matches your device. This value is
# available on response of GET call to callstatus.html but I am too lazy to do that as it doesn't 
# appear to change for me.
call_status_item=0x47d158

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -r  ==> reboot the device
  -s  ==> stop (hangup) the active call
  -a  ==> record audio of active call

  example: $my_name -r

EOF
  exit 1
}

# check environment variables
check_env() {

  # source the .obi_env if found
  if [ -f $obienv_file ] ; then
    set -o allexport
    source $obienv_file
  fi

  if [ -z ${OBI_HOST} ]; then
    echo "[INFO] OBI_HOST environment variable missing!" | tee -a $log_file
    exit 2
  fi

  if [ -z ${OBI_USER} ]; then
    echo "[INFO] OBI_USER environment variable missing!" | tee -a $log_file
    exit 3
  fi

  if [ -z ${OBI_PASSWORD} ]; then
    echo "[INFO] OBI_PASSWORD environment variable missing!" | tee -a $log_file
    exit 4
  fi
}

do_reboot() {
  local url="http://${OBI_HOST}/rebootgetconfig.htm"
  echo "[INFO] rebooting the OBi device ..." | tee -a $log_file
  wget --user="${OBI_USER}" --password="${OBI_PASSWORD}" -q -O $obi_output $url 2>&1 | tee -a $log_file
  cat $obi_output >> $log_file
  exit 0
}

do_hangup() {
  local url="http://${OBI_HOST}/callstatus.htm?item=$call_status_item"  
  echo "[INFO] attempting to hangup the active call on OBi device ..." | tee -a $log_file
  wget --user="${OBI_USER}" --password="${OBI_PASSWORD}" -q -O $obi_output $url 2>&1 | tee -a $log_file
  cat $obi_output >> $log_file
  exit 0
}

do_record() {
  local url="http://${OBI_HOST}/record.au?port=$port"

  if [ ! -d $audio_path ]; then
    echo "[ERROR] audio_path ($audio_path) directory missing, create and retry!" | tee -a $log_file
    exit 5
  fi

  cd $audio_path || exit 6
  audio_file="$audio_path/$(date +%b_%d_%Y-%H_%M).au"

  echo "[INFO} saving audio to: $audio_file ..." | tee -a $log_file
  wget --user="${OBI_USER}" --password="${OBI_PASSWORD}" -q  --output-document="$audio_file" $url 2>&1 | tee -a $log_file
  exit 0
}

# ---------------- main entry --------------------
echo "[INFO] $my_name starting ..." | tee $log_file
check_env

# commandline parse
while getopts $options opt; do
  case $opt in
    r)
      do_reboot
      ;;
    s)
      do_hangup
      ;;
    a)
      do_record
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

echo "[ERROR] missing args!" | tee -a $log_file
usage
