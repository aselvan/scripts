#!/usr/bin/env bash
#
# host_info.sh --- show hostname, IP & MAC address of active LAN hosts.
#
# Note: the output is /etc/host format so you can append output to your /etc/hosts if desired.
#
# Author:  Arul Selvan
# Created: Oct 2, 2023
#

# version format YY.MM.DD
version=23.11.15
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="show hostname, IP & MAC address of active LAN hosts"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

arp_entries="/tmp/$(echo $my_name|cut -d. -f1).txt"
options="i:m:n:vh?"
link_local="169.254"
ip_address=""
mac_address=""
iface="en0"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
cat << EOF

$my_name - $my_title

Usage: $my_name [options]
  -i <iface> ---> network interface to use [default: $iface]
  -v         ---> verbose mode prints info messages, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name -i en0
  
EOF
  exit 0
}

get_my_ip() {
  local my_ip=""
  if [ $os_name = "Darwin" ]; then
    my_ip=`ipconfig getifaddr $iface`
  else
    my_ip=`ip addr show $iface | grep 'inet '|grep 'scope global'| awk '{print $2}' |cut -f1 -d'/'`    
  fi
  echo $my_ip
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
    i)
      iface=$OPTARG
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# get the network CIDR
my_ip=$(get_my_ip)
if [ "$my_ip" = "" ] ; then
  log.error "Unable to determine your interface IP, may be interface ($iface) is not active? ... exiting"
  exit 1
fi
my_net=`echo $my_ip |awk -F. '{print $1"."$2"."$3".0/24"; }'`

# ensure we are not on link-local i.e. not connected to anywhere
if [[ *"$my_net"* = *"$link_local"* ]] ; then
  log.error "You are on link-local ($my_net) i.e. not connected to any network... exiting"
  exit 2
fi

# make sure interface is active
iface_status=`ifconfig $iface | grep status|awk -F: '{print $2}'`
if [[ $iface_status = *"inactive"* ]] ; then
  log.error "interface $iface is not active ... exiting"
  exit 3
fi

# collect mac on the network 
log.stat "Scanning net $my_net"
nmap --host-timeout 3 -T5 $my_net >/dev/null 2>&1
arp -an|egrep -v 'incomplete|ff:ff:ff:ff|169.254|224.|239.|.255)'> $arp_entries

cat $arp_entries | while read -r line ; do
  ip=$(echo $line|awk -F '[()]|at | on ' '{print $2}')
  mac=$(echo $line|awk -F '[()]|at | on ' '{print $4}')
  host=`dig +short -x $ip|sed -e 's/\.$//'`
  echo "$ip $host $host # macaddress: $mac"
done
