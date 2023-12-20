#!/usr/bin/env bash
#
# dhcp_leases.sh --- Parse and display DHCP lease expiry from dnsmasq lease file
#
# Note: This file is typically found on any router or dhcp host server at the 
#   location /var/lib/misc/dnsmasq.leases. It can be downloaded and fed to this 
#   script to parse the information. If you have keybased ssh access to your 
#   router you can simply pipe it to this script as shown below
#
#   ssh <yourhost> cat /var/lib/misc/dnsmasq.leases | dhcp_leases.sh
#      
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=23.11.15
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Parse and display DHCP lease expiry from dnsmasq lease file"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="f:n:m:i:vh?"
leases_file="/dev/stdin"
search_host=""
search_mac=""
search_ip=""
expiry=""
mac=""
ip=""
host=""
client_id=""

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -f <file>  ---> dnsmasq.leases file [default: '$leases_file']
  -n <host>  ---> specific hostname to search for displaying lease info [default: all]
  -i <ip>    ---> specific ip to search for displaying lease info [default: all]
  -m <mac>   ---> specific macaddress to search for displaying lease info [default: all]
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name -f /var/lib/misc/dnsmasq.leases
example: cat leases_file | $my_name
  
EOF
  exit 0
}

print_lease_info() {
  log.stat "  Host: ${host}, IP: ${ip}, MAC: ${mac}"
  log.stat "    Lease expires on: $(convert_seconds $expiry 1)" $green
}

parse_leases_file() {
  while read line ; do
    read -r expiry mac ip host client_id  <<< $line
    log.debug "Expiry: $expiry ; MAC: $mac ; IP: $ip ; Host: $host ; ClientID: $client_id"
    if [ ! -z "$search_host" ] ; then
      if [ "$host" = "$search_host" ] ; then
        print_lease_info
        exit 0
      else
        continue
      fi
    elif [ ! -z "$search_mac"  ] ; then
      if [ "$mac" = "$search_mac" ] ; then
        print_lease_info
        exit 0
      else
        continue
      fi
    elif [ ! -z "$search_ip"   ] ; then
      if [ "$ip" = "$search_ip" ] ; then
        print_lease_info
        exit 0
      else
        continue
      fi
    else
      print_lease_info
    fi
  done < "${leases_file}"
}


# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
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
    f)
      leases_file="$OPTARG"
      ;;
    n)
      search_host="$OPTARG"
      ;;
    m)
      search_mac="$OPTARG"
      ;;
    i)
      search_ip="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

parse_leases_file

