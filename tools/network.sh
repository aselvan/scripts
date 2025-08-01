#!/usr/bin/env bash
###############################################################################
#
# network.sh --- Wrapper for many useful network commands.
#
# Though these info are readily available with different commandline tools, this script
# is a hany wrapoper to get a simple output of all you need to know.
#
# Author:  Arul Selvan
# Created: Jul 29, 2023
#
###############################################################################
# Version History:
#   Jul 29, 2023 --- Original version
#   Nov 26, 2024 --- Renamed to network.sh (was network_info.sh) and added new functionality
#   Dec 25, 2024 --- Added wifi stats, ssid etc
#   Mar 18, 2025 --- Use effective_user in place of get_current_user. Also
#                    implemented interface related functions in Linux
#   Jun 3,  2025 --- Added restoremac command
#   Jun 5,  2025 --- Added speed test command
#   Jun 30, 2025 --- Added openport command
#   Jul 12, 2025 --- Added help syntax for each supported commands
###############################################################################

# version format YY.MM.DD
version=25.07.12
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl network tools wrapper all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
my_mac_addr_file="$HOME/.my_mac_address"

# commandline options
options="c:i:n:s:H:d:m:a:p:vh?"

command_name=""
supported_commands="info|ip|lanip|wanip|mac|dhcp|scan|testsvc|testfw|interfaces|traceroute|dnsperf|multidnsperf|allports|tcpports|listenports|spoofmac|restoremac|genmac|route|dns|netstat|appfirewall|dhcprenew|wifiif|ssid|wifistats|internet|speed|openport"
# if -h argument comes after specifiying a valid command to provide specific command help
command_help=0
iface=""
my_mac=""
wifi_iface=""
my_net="192.168.1.0/24"
my_ip=""
wan_ip=""
host_port=""
traceroute_count=15
multidnsperf_hosts="yahoo.com microsoft.com ibm.com google.com chase.com fidelity.com citi.com capitalone.com selvans.net selvansoft.com"
dns_server=""
mac_to_spoof=""
additional_args=""
netstat_args="-f inet -a -p tcp"
appfirewall="/usr/libexec/ApplicationFirewall/socketfilterfw"
appfirewall_args="--listapps --getglobalstate --getblockall  --getstealthmode"
wait_time=5
ssid=""
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
ports=""

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name -c <command> [options]
  -c <command> [-h] ---> command to run [see supported commands below] -h to show command syntax
  -i <interface>    ---> network interface to use for various commands that needs interface
  -n <network>      ---> optional CIDR address to scan [used in 'scan' command Default: $my_net]
  -s <host:[port]>  ---> Host and port to test [Needed for commands like 
                         "testsvc|textfw|traceroute|dnsperf|openport" etc.
  -p <ports>        ---> Single port or comma separated list of ports in doublequotes [used by openport command]
  -H <hostlist>     ---> List of hosts to perform dns lookup performance [used in multidnsperf command]
  -d <dnsserver>    ---> Custom DNS server to use for resolving insead of default [used in multidnsperf]
  -m <macaddress>   ---> Required argument for spoofmac command i.e. mac address to spoof
  -a <args>         ---> Additional args used for commands like netstat|appfirewall etc
  -v                ---> enable verbose, otherwise just errors are printed
  -h                ---> print usage/help
NOTE: For commands requiring args add -h after the command to see command specific usage. 
Ex: $my_name -c openport -h

Supported commands: 
  $supported_commands

See also: 
  macos.sh process.sh security.sh

EOF
  exit 0
}

function not_implemented() {
  log.warn "Not implemented for $os_name OS yet, exiting..."
  exit 99
}
function get_wifi_interface_linux() {
  not_implemented
}
function get_ssid_linux() {
  not_implemented
}
function get_wifistats_linux() {
  not_implemented
}

function get_interface_linux() {
  # Loop through each interface
  for i in $(ls /sys/class/net); do
    local mac_addr=$(cat /sys/class/net/"$i"/address)
    local ipaddr=$(ip -4 addr show "$i" 2>/dev/null |egrep "global|host"|awk '{print $2}'|| echo "N/A")

    # Check if the interface is active (UP)
    local state=$(cat /sys/class/net/"$i"/operstate)
    if [[ "$state" == "up" ]]; then
      iface=$i
      log.debug "Using interface: $iface"
      return
    fi
    log.error "No active interface found ... exiting"
    exit 10
  done
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

function get_wifi_interface_mac() {
  wifi_iface=`networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}'`
  log.stat "\tWiFi interface: $wifi_iface"
}

function get_wifi_interface() {
  case $os_name in 
    Darwin)
      get_wifi_interface_mac
      ;;
    Linux)
      get_wifi_interface_linux
      ;;
    *)
      not_implemented
      ;;
  esac
}

function get_ssid_mac() {
  ssid=`system_profiler SPAirPortDataType | awk '/Current Network Information/ {getline; gsub(":", ""); print $NF; exit}'`
  log.stat "\tSSID:        $ssid"
}

function get_ssid() {
  case $os_name in 
    Darwin)
      get_ssid_mac
      ;;
    Linux)
      get_ssid_linux
      ;;
    *)
      not_implemented
      ;;
  esac
}

function get_wifistats_mac() {
  check_root

  local rssi=`wdutil info | grep 'RSSI'|awk -F: '{print $2}'`
  local noise=`wdutil info | grep 'Noise'|awk -F: '{print $2}'`
  local txrate=`wdutil info | grep 'Tx Rate'|awk -F: '{print $2}'`
  local enc_type=`wdutil info | grep 'Security'|awk -F: '{print $2}'`
  local phy_mode=`wdutil info | grep 'PHY Mode'|awk -F: '{print $2}'`
  local channel=`wdutil info|egrep '^    Channel[[:space:]]+:'|awk -F: '{print $2}'`

  get_ssid
  log.stat "\tPHY Mode:   $phy_mode"
  log.stat "\tChannel:    $channel"
  log.stat "\tEncryption: $enc_type"
  log.stat "\tRSSI:       $rssi [-50 to -60: Excellent; -70 to -80: Fair ; < -80: Poor]"
  log.stat "\tNoise:      $noise [-120 to -90: Excellent; -90 to -70: Fair; > -70: Poor]" 
  log.stat "\tTx Rate:    $txrate"
}

function get_wifistats() {
  case $os_name in 
    Darwin)
      get_wifistats_mac
      ;;
    Linux)
      get_wifistats_linux
      ;;
    *)
      not_implemented
      ;;
  esac
}

# get current IP and network CIDR
function get_ip_and_network() {

  case $os_name in 
    Darwin)
      my_ip=`ipconfig getifaddr $iface`
      if [ -z $my_ip ] ; then
        my_ip="N/A"
      fi
      ;;
    Linux)
      # note grab the second one which is realip, the first one is link-local
      my_ip=`hostname -I | awk '{print $2}'`
      ;;
    *)int
      not_implemented
      ;;
  esac

  wan_ip=`curl -s ifconfig.me`
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
  echo $mac_addr | $pbc
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
  if [ $command_help -eq 1 ] ||  [ -z "$host_port" ]  ; then
    if [ -z $host_port ] ; then
      log.error "Need host:port for testsvc command"
    fi
    log.stat "Usage: $my_name -c testsvc -s yahoo.com:443  # check host:port is active using netcat " $black
    exit 1
  fi

  host="${host_port%%:*}"
  port="${host_port##*:}"
  log.debug "Checking service on $host at port $port ..."
  result=$(nc -zv -w10 -G10 $host $port 2>&1)
  log.stat "\t$result" $green
}

function list_interfaces_mac() {
  for i in `ipconfig getiflist` ; do
    local mac_addr=`ifconfig $i | grep ether| awk '{print $2;}'`  
    local ipaddr=`ipconfig getifaddr $i`
    if [ ! -z "$ipaddr" ] ; then
      log.stat "\t$i : active ; MAC: $mac_addr; IP: $ipaddr" $green
    else
      log.stat "\t$i : inactive ; MAC: $mac_addr; IP: N/A" $red
    fi
  done
}

function list_interfaces_linux() {
  # Loop through each interface
  for i in $(ls /sys/class/net); do
    local mac_addr=$(cat /sys/class/net/"$i"/address)
    local ipaddr=$(ip -4 addr show "$i" 2>/dev/null |egrep "global|host"|awk '{print $2}'|| echo "N/A")

    # Check if the interface is active (UP)
    local state=$(cat /sys/class/net/"$i"/operstate)
    if [[ "$state" == "up" ]]; then
      log.stat "\t$i : active ; MAC: $mac_addr; IP: $ipaddr" $green
    else
      log.stat "\t$i : inactive ; MAC: $mac_addr; IP: $ipaddr" $red      
    fi
  done
}

# list all the interfaces in this host
function list_interfaces() {
  case $os_name in 
    Darwin)
      list_interfaces_mac
      ;;
    Linux)
      list_interfaces_linux
      ;;
    *)
      not_implemented
      ;;
  esac
}

function testfw() {
  if [ $command_help -eq 1 ] ||  [ -z "$host_port" ]  ; then
    if [ -z $host_port ] ; then
      log.error "Need host:port for testfw command"
    fi
    log.stat "Usage: $my_name -c testfw -s yahoo.com:443  # check host:port is active using nmap " $black
    exit 1
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

  if [ $command_help -eq 1 ] ||  [ -z "$host_port" ]  ; then
    if [ -z $host_port ] ; then
      log.error "Need host for traceroute command"
    fi
    log.stat "Usage: sudo $my_name -c traceroute -s yahoo.com  # traceroute using nmap " $black
    exit 1
  fi

  host="${host_port%%:*}"
  log.stat "Traceroute to $host using nmap ..."
  nmap -sn --traceroute $host
}

function dnsperf() {
  if [ $command_help -eq 1 ] ||  [ -z "$host_port" ]  ; then
    if [ -z $host_port ] ; then
      log.error "Need host for dnsperf command"
    fi
    log.stat "Usage: $my_name -c dnsperf -s yahoo.com  # traceroute using nmap " $black
    exit 1
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

restoremac() {
  # check for root access
  check_root

  if [ ! -f $my_mac_addr_file ] ; then
    log.warn "no previously saved mac file ($my_mac_addr_file) found to restore from! ... exiting"
    exit 1
  else
    my_mac=`cat $my_mac_addr_file`
  fi    

  log.stat "\trestoring mac to $my_mac ..."
  if [ $os_name = "Darwin" ]; then
    networksetup -setairportpower $iface off
    sleep 1
    networksetup -setairportpower $iface on
    ifconfig $iface ether $my_mac >/dev/null 2>&1
    ifconfig $iface down
    log.stat "\tSleeping ..."
    sleep 5
    ifconfig $iface up
  else
    ifconfig $iface hw ether $my_mac
  fi
  log.stat "\tmac restored"
}

save_mac() {
  if [ ! -f $my_mac_addr_file ] ; then
    log.debug "no previously saved mac file ($my_mac_addr_file) found!"
    log.debug "saving current mac address as saved mac address"
    my_mac=`ifconfig $iface|grep ether|awk '{print $2;}'`
    echo $my_mac > $my_mac_addr_file
    log.stat "\tsaved my mac address ($my_mac)."
  else
    my_mac=`cat $my_mac_addr_file`
    log.stat "\tmy mac address $my_mac was already saved."
  fi
}

function spoofmac() {
  # check for root access
  check_root
 
  if [ $command_help -eq 1 ] ||  [ -z "$mac_to_spoof" ]  ; then
    if [ -z $mac_to_spoof ] ; then
      log.error "Need mac address to spoof for spoofmac command"
    fi
    local mac_example=`openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//"`
    log.stat "Usage: $my_name -c spoofmac -m $mac_example # spoof macaddress to specified address " $black
    exit 1
  fi
 
  # save mac for restoring.
  save_mac

  local cur_mac=`ifconfig $iface | grep ether| awk '{print $2;}'`
  log.stat "\tCurrent  MAC on $iface: $cur_mac"
  log.stat "\tSpoofing MAC on $iface: $mac_to_spoof"

  networksetup -setairportpower $iface off
  sleep 1
  networksetup -setairportpower $iface on
  ifconfig $iface ether $mac_to_spoof >/dev/null 2>&1
  local cur_mac=`ifconfig $iface | grep ether| awk '{print $2;}'`
  if [ $cur_mac = "$mac_to_spoof" ] ; then
    log.stat "\tSpoofed $mac_to_spoof succesfully!" $green
    log.stat "\tToggling $iface down/up ..."
    ifconfig $iface down
    log.stat "\tSleeping ..."
    sleep 5
    ifconfig $iface up
    log.stat "\tToggled $iface down/up."
  else
    log.stat "\tSpoofing failed on $mac_to_spoof!" $red
  fi
}

function genmac() {
  local random_mac=`openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//"`
  log.stat "\tRandomly generated MAC: $random_mac" $green
}

function do_route() {
  check_installed ip
  local default_route=`ip route show |grep default`
  echo $default_route | $pbc
  log.stat "\tDefault route: $default_route" $green
}

function do_dns() {
  check_installed scutil
  log.stat "System wide DNS server(s)"
  log.stat "-------------------------"
  local dns_info=`scutil --dns |grep nameserver|sort -u`
  log.stat "$dns_info" $green

  log.stat "\nPer Device DNS servers"
  log.stat "-----------------------"
  readarray -t services < <(networksetup -listallnetworkservices | tail -n +2)
  for service in "${services[@]}"; do
    log.stat "Service: $service"
    networksetup -getdnsservers "$service"
  done
}

function do_netstat() {
  local netstat_info=`netstat $netstat_args $additional_args`
  log.stat "$netstat_info" $green

}

function do_appfirewall() {
  if [ ! -x $appfirewall ] ; then
    log.error "$appfirewall binary is missing..."
    exit 10
  fi
  local appfirewall_info=`$appfirewall $appfirewall_args $additional_args`
  log.stat "$appfirewall_info" $green

}

function do_dhcprenew() {
  # TODO: Need to find why the exclamation in wifi icon is stuck and then enable this feature.
  log.stat "NOT IMPLEMENTED: need to fix the exclamation issue on wifi icon first"
  return

  # check for root access
  check_root
  
  log.stat "Attempting to renew DHCP on interface $iface ..."
  #echo "add State:/Network/Interface/$iface/RefreshConfiguration temporary" | sudo scutil
  
  sudo ipconfig set $iface BOOTP
  log.stat "\tSwitched to bootp and waiting for $wait_time sec ..."
  sleep $wait_time
  log.stat "\tSwitch to DHCP now ..."
  sudo ipconfig set $iface DHCP
  log.stat "\tShould be renewed now."
}

check_internet() {
  log.stat "Checking internet connectivity ... "
  ping -c3 8.8.8.8 >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    log.error "  No internet connectvity!"
  else
    log.stat "  Internet available!" $green
  fi
}

test_speed() {
  if [ $os_name = "Darwin" ] ; then
    networkquality -s
  else
    check_installed speedtest-cli
    speedtest-cli --simple
  fi
}

function openport() {

  if [ $command_help -eq 1 ] ||  [ -z "$host_port" ]  ; then
    if [ -z $host_port ] ; then
      log.error "Need host, optionally comma separted ports for openport command"
    fi
    log.stat "Usage: $my_name -c openport -s 192.168.1.1 -p \"21, 22, 80, 443\" # check if listed ports are open using netcat" $black
    exit 1
  fi

  local host="${host_port%%:*}"
  if [ ! -z "$ports" ] ; then
    log.stat "Checking port(s) $ports on $host ..."
    IFS=',' read -ra port_array <<< "$ports"
    for p in "${port_array[@]}"; do
      nc -zv -w3 -G3 $host $p 2>&1
    done
  else
    log.stat "Checking all ports on $host. This will  take a long time..."
    confirm_action "Are you sure?"
    if [ $? -eq 1 ] ; then
      for (( i=0 ; i<1024 ; i++ )) ; do
        nc -zv -w1 -G1 $host $i 2>&1 | grep -E "succeeded|open"
      done
    else
      log.warn "Cancelled openport command!"
    fi
  fi
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

# pastebuffer depending on OS [note: used to copy certain things to paste buffer like ip, macc etc]
if [ $os_name = "Darwin" ]; then
  pbc='pbcopy'
else
  # Linux required X running, check if DISPLAY available, otherwise make this noop
  if [ -n "$DISPLAY" ]; then
    pbc='xsel --clipboard --input'
  else
    pbc="test"
  fi
fi


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
    p)
      ports="$OPTARG"
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
    a)
      additional_args="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      if [[ -n "$command_name" ]] && valid_command "$command_name" "$supported_commands" ; then
        command_help=1
      else
        usage
      fi
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
    echo $my_ip | $pbc
    log.stat "\tLAN IP: $my_ip on interface: $iface"
    log.stat "\tWAN IP: `curl -s ifconfig.me`"
    ;;
  lanip)
    echo $my_ip | $pbc
    log.stat "\tLAN IP: $my_ip on interface: $iface"
    ;;
  wanip)
    echo $wan_ip | $pbc
    log.stat "\tWAN IP: $wan_ip"
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
  tcpports)
    lsof -i tcp -P -n
    ;;
  allports)
    lsof -iTCP -iUDP -P -n
    ;;
  listenports)
    lsof -iUDP -iTCP -sTCP:LISTEN |grep \*
    ;;
  spoofmac)
    spoofmac
    ;;
  restoremac)
    restoremac
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
  netstat)
    do_netstat
    ;;
  appfirewall)
    do_appfirewall
    ;;
  dhcprenew)
    do_dhcprenew
    ;;
  wifiif)
    get_wifi_interface_mac
    ;;
  ssid)
    get_ssid
    ;;
  wifistats)
    get_wifistats
    ;;
  internet)
    check_internet
    ;;
  speed)
    test_speed
    ;;
  openport)
    openport
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac

