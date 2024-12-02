#!/usr/bin/env bash
#
# network.sh --- Wrapper for many useful network commands.
#
# Though these info are readily available with different commandline tools, this script
# is a hany wrapoper to get a simple output of all you need to know.
#
# Author:  Arul Selvan
# Created: Jul 29, 2023
#
# Version History:
#   Jul 29, 2023 --- Original version
#   Nov 26, 2024 --- Renamed to network.sh (was network_info.sh) and added new functionality
#

# version format YY.MM.DD
version=2024.11.26
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl network tools wrapper all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"

# commandline options
options="c:i:n:s:H:d:m:vh?"

command_name=""
supported_commands="info|ip|lanip|wanip|mac|dhcp|scan|testsvc|testfw|interfaces|traceroute|dnsperf|multidnsperf|allports|ports|spoofmac|genmac|route|dns"
iface=""
my_net="192.168.1.0/24"
my_ip=""
host_port=""
traceroute_count=15
multidnsperf_hosts="yahoo.com microsoft.com ibm.com google.com chase.com fidelity.com citi.com capitalone.com selvans.net selvansoft.com"
dns_server=""
mac_to_spoof=""

airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>     ---> command to run [see supported commands below]  
  -i <interface>   ---> network interface to use [Default: $iface]
  -n <network>     ---> optional CIDR address to scan [used in 'scan' command Default: $my_net]
  -s <host:[port]> ---> Host and port to test [Needed for commnans like "testsvc|textfw|traceroute|dnsperf" etc]
  -H <hostlist>    ---> List of hosts to perform dns lookup performance [used in multidnsperf command]
  -d <dnsserver>   ---> Custom DNS server to use for resolving insead of default [used in multidnsperf]
  -m <macaddress>  ---> Required argument for spoofmac command i.e. mac address to spoof
  -v               ---> enable verbose, otherwise just errors are printed
  -h               ---> print usage/help

Supported commands: $supported_commands  
example: $my_name -c info
  
EOF
  exit 0
}

function not_implemented() {
  log.warn "Not implemented for $os_name OS yet, exiting..."
  exit 99
}

reset_logfile_perm() {
  # just make sure the log file is writable for next run which is likely non-sudo
  chown $SUDO_USER $my_logfile
  if [ -f $ ] ; then
    chmod $SUDO_USER $arp_entries
  fi
}

function get_interface_linux() {
  not_implemented
}

# detect active, IP assigned interface. The first one is returned
function get_interface_mac() {
  local ipaddr
  for iface in `ipconfig getiflist` ; do
    ipaddr=`ipconfig getifaddr $iface`
    if [ ! -z "$ipaddr" ] ; then
      log.debug "Using interface: $iface"
      return
    fi
  done
  iface="en0"
  log.debug "Using interface: $iface"
}
function get_interface() {
  case $os_name in 
    Darwin)
      get_interface_mac
      ;;
    Linux)
      get_interface_linux
      ;;
    *)
      not_implemented
      ;;
  esac
}

# get current IP and network CIDR
function get_ip_and_network() {
  my_ip=`ipconfig getifaddr $iface`

  case $os_name in 
    Darwin)
      my_ip=`ipconfig getifaddr $iface`
      if [ -z $my_ip ] ; then
        my_ip="N/A"
      fi
      ;;
    Linux)
      my_ip=`hostname -I | awk '{print $1}'`
      ;;
    *)
      not_implemented
      ;;
  esac
  my_net=`echo $my_ip |awk -F. '{print $1"."$2"."$3".0/24"; }'` 
  
}


function info_mac() {
  local dev_string=$1
  lease_secs=`ipconfig getoption $iface lease_time`
  log.stat "Total number of interfaces available: `ipconfig ifcount`"
  # read IP, MAC ... etc
  log.stat "\tInterface:    $iface" $green
  log.stat "\tStatus:       `ifconfig $iface|awk '/status/ {print $2}'`" $green
  log.stat "\tMAC Address:  `ifconfig $iface  | awk '/ether/ {print $2}'`" $green
  log.stat "\tIP Address:   `ipconfig getifaddr $iface`" $green
  log.stat "\tMask:         `ipconfig getoption $iface subnet_mask`" $green
  log.stat "\tDNS:          `ipconfig getoption $iface domain_name_server`" $green
  log.stat "\tGateway:      `ipconfig getoption $iface router`" $green
  log.stat "\tBroadcast:    `ipconfig getoption $iface broadcast_address`" $green
  log.stat "\tDHCP Lease:   `ipconfig getoption $iface lease_time` seconds" $green
  log.stat "\t`networksetup -getMTU $iface`" $green

  # if this is a Wi-Fi interface get Wi-Fi details
  networksetup -getairportnetwork $iface 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then
    log.stat "\r`system_profiler SPAirPortDataType | grep -A 20 $iface`"
    
    #rssi=`$airport -I |awk '/ agrCtlRSSI:/ {print $2}'`
    #noise=`$airport -I |awk '/ agrCtlNoise:/ {print $2}'`
    #log.stat "\t`networksetup -getairportpower $iface`" $green
    #log.stat "\tWi-Fi Name:         `$airport -I |awk '/ SSID:/ {print $2}'`" $green
    #log.stat "\tWi-Fi Channel:      `$airport -I |awk '/ channel:/ {print $2}'`" $green
    #log.stat "\tWi-Fi Auth:         `$airport -I |awk '/ link auth:/ {print $3}'`" $green
    #log.stat "\tWi-Fi Channel:      `$airport -I |awk '/ channel:/ {print $2}'`" $green
    #log.stat "\tWi-FI RSSI:         $rssi [range: (-100,0) note: closer to 0 is better, ex: -55 is pretty damn good]" $green
    #log.stat "\tWi-Fi Noise:        $noise [range: (-120,0) note: closer to -120 is better]" $green
    #log.stat "\tWi-Fi Quality:      $((rssi - noise)) [should be at least 20 or greater]" $green
    #log.stat "\tWi-Fi Last TxnRate: `$airport -I |awk '/ lastTxRate:/ {print $2}'` mbps" $green
  fi
}

function info() {
  case $os_name in 
    Darwin)
      info_mac
      ;;
    Linux)
      not_implemented
      ;;
    *)
      not_implemented
      ;;
  esac
}

function showmac() {
  mac_addr=`ifconfig $iface | grep ether| awk '{print $2;}'`
  log.stat "\tCurrent MAC address of $iface is: $mac_addr" $green
}

function showdhcp() {
  case $os_name in 
    Darwin)
      log.stat "\t`ipconfig getpacket $iface`"
      ;;
    Linux)
      not_implemented
      ;;
    *)
      not_implemented
      ;;
  esac
}

function scannetwork() {
  nmap --host-timeout 10 -T5 $my_net >/dev/null 2>&1
  arp -an|egrep -v 'incomplete|ff:ff:ff:ff|169.254|224.|239.|.255)'> $arp_entries

  log.stat "\tIP\t\tHost\tMAC Address"
  cat $arp_entries | while read -r line ; do
    ip=$(echo $line|awk -F '[()]|at | on ' '{print $2}')
    mac=$(echo $line|awk -F '[()]|at | on ' '{print $4}')
    host=`dig +short +timeout=1 +retry=0 +nostats -x $ip|sed -e 's/\.$//'`
    if [[ $host == "" || $host == *"communications error"* || $host == *"connection timed out"* ]] ; then
      host="N/A"
    fi
    log.stat "\t$ip\t$host\t$mac" $green
  done
}

function testsvc() {
  if [ -z $host_port ] ; then
    log.error "Need host:port for testsvc function, see usage"
    usage
  fi
  host="${host_port%%:*}"
  port="${host_port##*:}"
  log.debug "Checking service on $host at port $port ..."
  result=$(nc -zv -w10 -G10 $host $port 2>&1)
  log.stat "\t$result" $green
}

# list all the interfaces in this host
function list_interfaces() {
  for i in `ipconfig getiflist` ; do
    mac_addr=`ifconfig $i | grep ether| awk '{print $2;}'`  
    ipaddr=`ipconfig getifaddr $i`
    if [ ! -z "$ipaddr" ] ; then
      log.stat "\t$i : active ; MAC: $mac_addr; IP: $ipaddr" $blue
    else
      log.stat "\t$i : inactive ; MAC: $mac_addr; IP: N/A" $green
    fi
  done
}

function testfw() {
  if [ -z $host_port ] ; then
    log.error "Need host:port for testfw function, see usage"
    usage
  fi
  host="${host_port%%:*}"
  port="${host_port##*:}"
  log.debug "Checking port open on $host at port $port ..."
  result=$(nmap -Pn -sT -p $port $host | grep -E '^[0-9]+/(tcp|udp)' | awk '{print $1, $2, $3}')
  log.stat "\t$result" $green
}

function traceroute() {
  # check for root access
  check_root

  if [ -z $host_port ] ; then
    log.error "Need host for traceroute function, see usage"
    usage
  fi
  host="${host_port%%:*}"

  log.stat "Traceroute to $host using nmap ..."
  nmap -sn --traceroute $host

  reset_logfile_perm
}

function dnsperf() {
  if [ -z $host_port ] ; then
    log.error "Need host:port for traceroute function, see usage"
    usage
  fi
  host="${host_port%%:*}"
  log.stat "Running dnsperf to resolve host $host ..."
  result=$(dig $host +noall +answer +stats | awk '$3 == "IN" && $4 == "A"{ip=$5}/Query time:/{t=$4 " " $5}END{print ip, t}')
  log.stat "\t$result" $green
}

function multidnsperf() {
  # Run dig for all hostnames at once and extract query times
  local total_time=0
  if [ -z $dns_server ] ; then
    log.stat "Using default DNS resolver ..."
    output=$(dig +noall +answer +stats $multidnsperf_hosts | grep "Query time:" | awk '{print $4}')
  else
    log.stat "Using custom DNS resolver: $dns_server ..."
    output=$(dig +noall +answer +stats $multidnsperf_hosts @$dns_server | grep "Query time:" | awk '{print $4}')
  fi

  # Sum up the query times
  for time in $output; do
    total_time=$((total_time + time))
  done

  log.stat "\tTotal time for resolving all hostnames: $total_time ms" $green
}

function spoofmac() {
  # check for root access
  check_root
  
  if [ -z $mac_to_spoof ] ; then
    log.error "Need a mac address to spoof, see usage"
    usage
  fi
 
  local cur_mac=`ifconfig $iface | grep ether| awk '{print $2;}'`
  log.stat "\tCurrent  MAC on $iface: $cur_mac"
  log.stat "\tSpoofing MAC on $iface: $mac_to_spoof"

  networksetup -setairportpower en0 off
  sleep 1
  networksetup -setairportpower en0 on
  ifconfig $iface ether $mac_to_spoof >/dev/null 2>&1
  local cur_mac=`ifconfig $iface | grep ether| awk '{print $2;}'`
  if [ $cur_mac = "$mac_to_spoof" ] ; then
    log.stat "\tSpoofed $mac_to_spoof succesfully!" $green
  else
    log.stat "\tSpoofing failed on $mac_to_spoof!" $red
  fi
  reset_logfile_perm
}

function genmac() {
  local random_mac=`openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//"`
  log.stat "\tRandomly generated MAC: $random_mac" $green
}

function do_route() {
  check_installed ip
  local default_route=`ip route show |grep default`
  log.stat "\tDefault route: $default_route" $green

}
function do_dns() {
  check_installed scutil
  local dns_info=`scutil --dns |grep nameserver`
  log.stat "\tDNS Servers: $dns_info" $green

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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    i)
      iface="$OPTARG"
      ;;
    s)
      host_port="$OPTARG"
      ;;
    n)
      network="$OPTARG"
      ;;
    H)
      multidnsperf_hosts="$OPTARG"
      ;;
    d)
      dns_server="$OPTARG"
      ;;
    m)
      mac_to_spoof="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing arguments, see usage below"
  usage
fi

if [ -z $iface ] ; then
  get_interface
fi
get_ip_and_network

# run different wrappes depending on the command requested
case $command_name in
  info)
    info
    ;;
  mac)
    showmac
    ;;
  ip)
    log.stat "\tLAN IP: $my_ip on interface: $iface"
    log.stat "\tWAN IP: `curl -s ifconfig.me`"
    ;;
  lanip)
    log.stat "\tLAN IP: $my_ip on interface: $iface"
    ;;
  wanip)
    log.stat "\tWAN IP: `curl -s ifconfig.me`"
    ;;
  dhcp)
    showdhcp
    ;;
  scan)
    log.stat "Scanning network $my_net using interface $iface ... [NOTE: make sure $iface is correct]"
    scannetwork
    ;;
  testsvc)
    testsvc
    ;;
  interfaces)
    list_interfaces
    ;;
  testfw)
    testfw
    ;;
  traceroute)
    traceroute
    ;;
  dnsperf)
    dnsperf
    ;;
  multidnsperf)
    multidnsperf
    ;;
  ports)
    lsof -i tcp -P -n
    ;;
  allports)
    lsof -i -P -n
    ;;
  spoofmac)
    spoofmac
    ;;
  genmac)
    genmac
    ;;
  route)
    do_route
    ;;
  dns)
    do_dns
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac

