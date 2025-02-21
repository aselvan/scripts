#!/usr/bin/env bash
#
# sample.sh --- handy generic sample template to create new script
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#
# Version History:
#   Jul 19, 2022 --- Original version
#   Dec 9,  2024 --- Updated usage function.
#

# version format YY.MM.DD
version=24.05.19
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="e:vh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title


Usage: $my_name [options]
  -e <email> ---> email address to send success/failure messages
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name -h -v
  
EOF
  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

# check pidof function
echo "PIDS: $(pidof "bash")"

#check_installed "required_binary"
#check_root

# parse commandline options
while getopts $options opt ; do
  case $opt in
    e)
      email_address="$OPTARG"
      ;;
    v)
      verbose=1
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

# seconds/mseconds to date conversion
date_st=$(convert_mseconds 1686709485000 0)
echo "1686709485000 msec will map to human readble date: $date_st"
date_st=$(convert_mseconds 1686709485000 1)
echo "1686709485000 msec from now to human readble date: $date_st"

# conversion function
v2mv=$(v2mv 3.2)
echo "Volt/mVolt: 3.2/$v2mv"

