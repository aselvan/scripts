#!/usr/bin/env bash
#
# sample.sh --- handy generic sample template to create new script
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=23.05.02
my_name="`basename $0`"
my_version="`basename $0` v$my_version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"

# commandline options
options="e:vh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# include logger and functions (requires these files in same path as this script)
source $my_path/logger.sh
source $my_path/functions.sh

usage() {
  cat << EOF

  $my_name $my_title

  Usage: $my_name [options]
     -e <email>    ---> email address to send success/failure messages
     -v            ---> verbose mode prints info messages, otherwise just errors are printed
     -h            ---> print usage/help

  example: $my_name -h
  
EOF
  exit 0
}

# ----------  main --------------
log.init $my_logfile
#check_installed "required_binary"
#check_root

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
if [ $? -eq 1 ] ; then
  log.stat "Confirm: YES"
else
  log.stat "Confirm: NO"
fi
check_connectivity
if [ $? -eq 0 ] ; then
  log.info "we have connectivity!"
else
  log.info "We don't have network connectivity!"
fi

path_separate "/var/log/apache2/access.log"
date_st=$(msec_to_date "1686709485000")
echo "Converted 1686709485000 to human readble date: $date_st"
