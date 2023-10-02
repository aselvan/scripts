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
version=23.10.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
os_name=`uname -s`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
arp_entries="/tmp/$(echo $my_name|cut -d. -f1).txt"
log_init=0
options="i:m:n:vh?"
verbose=0
failure=0
green=32
red=31
blue=34

link_local="169.254"
ip_address=""
mac_address=""
iface="en0"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  $my_name --- show hostname, IP & MAC address of active LAN hosts.

  Usage: $my_name [options]
     -i <iface> ---> network interface to use [default: $iface]
     -v         ---> verbose mode prints info messages, otherwise just errors are printed
     -h         ---> print usage/help

  example: $my_name -i 192.168.1.10
  
EOF
  exit 0
}

# -- Log functions ---
log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}
log.stat() {
  log.init
  local msg=$1
  local color=$2
  if [ -z $color ] ; then
    color=$blue
  fi
  echo -e "\e[0;${color}m$msg\e[0m" | tee -a $log_file 
}
log.warn() {
  log.init
  local msg=$1
  echo -e "\e[0;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[0;31m$msg\e[0m" | tee -a $log_file 
}

get_my_ip() {
  local my_ip=""
  if [ $os_name = "Darwin" ]; then
    my_ip=`ipconfig getifaddr $iface`
  else
    my_ip=`ip addr show $iface | grep 'inet ' | awk '{print $2}' |cut -f1 -d'/'`    
  fi
  echo $my_ip
}

# ----------  main --------------
log.init

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
  host=`dig +short -x $ip|sed -e 's/\.//'`
  echo "$ip $host $host # macaddress: $mac"
done
