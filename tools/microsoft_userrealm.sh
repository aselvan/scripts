#!/usr/bin/env bash
###############################################################################
#
# microsoft_userrealm.sh --- Search/Validate microsoft account realm 
#
# This script can search login.microsoftonline.com to validate if the email
# provided is valid login.
#
# Author:  Arul Selvan
# Created: Oct 27, 2026
#
###############################################################################
# Version History: (original and last 3)
#   Oct 27, 2026 --- Original version
###############################################################################

# version format YY.MM.DD
version=26.10.27
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Search/Validate microsoft account realm"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
info_file="/tmp/$(echo $my_name|cut -d. -f1)_info.txt"

# commandline options
options="d:vh?"

realm_url="https://login.microsoftonline.com/getuserrealm.srf?json=1&login="
domain=""

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -d <domain> ---> domain address to check
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example(s):
  $my_name -d outlook.com

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

# check if jq present
check_installed jq

# parse commandline options
while getopts $options opt ; do
  case $opt in
    d)
      domain="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$domain" ] ; then
  log.error "Missing arguments, see usage below"
  usage
fi

curl -s "$realm_url$domain" | jq
