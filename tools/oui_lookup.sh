#!/usr/bin/env bash
#
# oui_lookup.sh --- lookup vendor name of MAC address 
#
# Credits: This wrapper script uses https://www.macvendorlookup.com to query MAC address
# 
# Author:  Arul Selvan
# Created: Dec 1, 2023
#

# version format YY.MM.DD
version=23.12.01
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Lookup vendor name of MAC address"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="a:vh?"
mac_address=""
oui_lookup_api="https://www.macvendorlookup.com/api/v2"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -a <macaddress> ---> Enter at least first 6 char (OUI part) of your MAC address 
  -v              ---> enable verbose, otherwise just errors are printed
  -h              ---> print usage/help

example: $my_name -a 001A11

Note: If first 6 char of mac address does not work enter full mac address

EOF
  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    a)
      mac_address="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $mac_address ] ; then
  log.error "Missing required argument MAC address"
  usage
fi

response=$(curl -s ${oui_lookup_api}/$mac_address/pipe)
if [ -z "$response" ] ; then
  log.error "Query failed, try with full macaddress!"
fi
log.debug "Response: $response"

# split the output into vars & print
IFS='|' read -r starthex endhex startdec enddec company address1 address2 address2 country dtype <<< $response
log.stat "  Vendor:  $company" $green
log.stat "  Address: ${address1}, ${address2} ${country}" $green
