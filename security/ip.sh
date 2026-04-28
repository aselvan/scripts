#!/usr/bin/env bash
################################################################################
# ip.sh --- various information on IP
#
#  This is a wrapper script over ip-api.com, a free API to check various info
#  of the ip provided via commandline
#
# Author:  Arul Selvan
# Created: Apr 28, 2026
#
# Preq:  jq (install with 'brew install jq')
#
# See Also: isphishing.sh ipabuse.sh ismalicious.sh ... etc
################################################################################
#
# Version History: (original & last 3)
#   Apr 28, 2024 --- Original version
################################################################################

# version format YY.MM.DD
version=26.04.28
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Various information on IP"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="a:c:l:vh?"

# variables
ip_output="/tmp/$(echo $my_name|cut -d. -f1).txt"
google_map_url=https://www.google.com/maps
ipapi_ep="http://ip-api.com/json"
all_fields="66846719"
ip=""
args=0

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -a <ip>  ---> All available data for that IP
  -c <ip>  ---> Check if the IP is VPN/proxy, mobile or hosting
  -l <ip>  ---> Get the geo location, clickable URL to show location
  -v       ---> enable verbose, otherwise just errors are printed
  -h       ---> print usage/help

Examples: 
  $my_name [Note: running with no argument will return your LAN and WAN ip]
  $my_name -c 1.1.1.1
  $my_name -a 8.8.8.8 [Note: all details of IP[

See also: isphishing.sh ipabuse.sh ismalicious.sh 

EOF
  exit 0
}

show_myip() {
  $scripts_github/tools/network.sh -cip
}

show_all_fields() {
  log.stat "All available details on $ip ..."
  curl -s ${ipapi_ep}/${ip}?fields=$all_fields | jq 
}

show_specific_fields() {
  log.stat "Check $ip for Proxy/VPN/Tor, Hosting/Colocated/Datacenter, Mobile connection ..."
  curl -s ${ipapi_ep}/${ip}?fields=status,proxy,hosting,mobile | jq > $ip_output
  status=$(cat $ip_output | jq -r '.status')
  if [ "$status" != "success" ] ; then
    log.error "API call failed reason=$status"
    return
  fi
  proxy=$(cat $ip_output | jq -r '.proxy')
  hosting=$(cat $ip_output | jq -r '.hosting')
  mobile=$(cat $ip_output | jq -r '.mobile')

  log.stat "  Proxy/VPN/TOR: $proxy"
  log.stat "  Hosting/Colocated/DataCenter: $hosting"
  log.stat "  Mobile: $mobile"
}

show_lat_lon() {
  log.stat "Lat/Lon of $ip ..."
  curl -s ${ipapi_ep}/${ip}?fields=status,lat,lon | jq > $ip_output 
  status=$(cat $ip_output | jq -r '.status')
  if [ "$status" != "success" ] ; then
    log.error "API call failed reason=$status"
    return
  fi
  lat=$(cat $ip_output | jq -r '.lat')
  lon=$(cat $ip_output | jq -r '.lon')
  log.stat "  ${google_map_url}?q=$lat,$lon"
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

# enforce required tools are presetnt
check_installed jq
create_writable_file $ip_output

# parse commandline options
while getopts $options opt ; do
  case $opt in
    a)
      args=1
      ip="$OPTARG"
      show_all_fields
      ;;
    c)
      args=1
      ip="$OPTARG"
      show_specific_fields
      ;;
    l)
      args=1
      ip="$OPTARG"      
      show_lat_lon
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# if no args provided print usage
if [ $args -eq 0 ] ; then
  show_myip
fi
