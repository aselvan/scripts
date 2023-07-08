#!/bin/bash
#
# firewall_install.sh --- install firewall rules on MacOS
#
# NOTE: Unfortunately, every MacOS update wipes the custom firewall rule we add in /etc/pf.conf
# so we need to repeat this after every MacOS update. You can always edit the /etc/pf.conf file 
# as expliained in the README.md file or use this handy handy script to make it easy to 
# reinstall the rules. 
#
# Author:  Arul Selvan
# Version: Jul 7, 2023
#

# version format YY.MM.DD
version=23.07.07
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="r:vh?"
verbose=0
anchor_name="com.selvansoft"
anchor_path="/etc/pf.anchors"
pf_conf="/etc/pf.conf"
rules_file="pf_rules_simple.conf"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -r <file>  ---> firewall rules file name to install [Default: $rules_file]
     -v         ---> verbose mode prints info messages, otherwise just errors are printed
     -h         ---> print usage/help

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
  write_log "[INFO]" "Start time:   `date +'%m/%d/%y %r'` ..."
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "Need root access to run this script, run with 'sudo $my_name'"
    exit
  fi
}


# ----------  main --------------
init_log
check_root
# parse commandline options
while getopts $options opt ; do
  case $opt in
    v)
      verbose=1
      ;;
    r)
      rules_file="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check if rules file is valid
if [ ! -f $rules_file ] ; then
  write_log "[ERROR]" "Invalid or non-existent rules file ($rules_file)!"
  usage
fi

# check if rules file already installed, if so bail out
cat $pf_conf |grep $anchor_name 2>&1 >/dev/null
if [ $? -eq 0 ] ; then
  write_log "[WARN]" "Firewall rules appear to be already installed, check ${pf_conf}"
  exit 1
fi

# copy rules file
cp $rules_file $anchor_path/.

write_log "[INFO]" "Adding firewall rules to $pf_conf ..."
# append rules
cat << EOF >> $pf_conf

#
# ------------------------ Custom firewall rules anchor ------------------------
# Disclaimer: This is a free utility from selvansoft.com provided "as is" without 
# warranty of any kind, express or implied. Use it at your own risk!
#
# Source: https://github.com/aselvan/scripts/tree/master/firewall
#
anchor "$anchor_name"
load anchor "$anchor_name" from "$anchor_path/`basename $rules_file`"

EOF
write_log "[STAT]" "Firewall rules are installed on ${pf_conf}"
write_log "[STAT]" "You now can run 'sudo firewall start' for rules take effect."
