#!/usr/bin/env bash
###############################################################################
#
# ghome.sh --- Search for googlehome devices and get information
#
# This script can search the home network and look for google home devices
# and prints out stats info offered by the device
#
# Author:  Arul Selvan
# Created: Jul 15, 2026
#
###############################################################################
# Version History: (original and last 3)
#   Jul 15, 2026 --- Original version
#   Jul 18, 2026 --- Added status command and fixed to run in Linux
###############################################################################

# version format YY.MM.DD
version=26.07.18
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Search for googlehome devices and get information"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
info_file="/tmp/$(echo $my_name|cut -d. -f1)_info.txt"

# commandline options
options="c:s:vh?"

command_name=""
supported_commands="info|scan|status"
iface=""
my_ip=""
my_net="192.168.1.0/24"
ghome_host=""
ghome_port=8008
nc_opt="-zv -w10 -G5"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name -c <command> [options]
  -c <command> [-h] ---> command to run [see supported commands below] 
  -s <host>         ---> Googlehome hostname [Needed for commands like 'info']
  -v                ---> enable verbose, otherwise just errors are printed
  -h                ---> print usage/help

example(s):
  $my_name -c info -s 192.168.1.55

Supported commands: 
  $supported_commands

See also: 
  network.sh

EOF
  exit 0
}

not_implemented() {
  log.warn "Not implemented for $os_name OS yet, exiting..."
  exit 99
}

# get current IP and network CIDR
get_my_network() {
  case $os_name in 
    Darwin)
      my_ip=`ipconfig getifaddr $iface`
      if [ -z $my_ip ] ; then
        log.error "Unable to find IP!"
        exit 1
      fi
      nc_opt="-zv -w10 -G5"
      ;;
    Linux)
      # note grab the second one which is realip, the first one is link-local
      my_ip=`hostname -I | awk '{print $2}'`
      nc_opt="-zv -w10"
      ;;
    *)
      not_implemented
      ;;
  esac
  my_net=`echo $my_ip |awk -F. '{print $1"."$2"."$3".0/24"; }'` 
}

get_interface_linux() {
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
get_interface_mac() {
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

get_interface() {
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

check_ghome_host() {
  if [ -z "$ghome_host" ] ; then
    log.error "Missing google home IP, a required argument, see usage"
    log.stat "usage: $my_name -c info -s <googlehome_ip>"
    usage
  fi
}

do_scan() {
  log.stat "Scanning ... (may take a min or two, be patient)"
  log.stat "  Scanning network for hosts ... "
  SECONDS=0
  nmap --host-timeout 10 -T5 $my_net >/dev/null 2>&1
  arp -an|egrep -v 'incomplete|ff:ff:ff:ff|169.254|224.|239.|.255)'> $arp_entries
  log.stat "  Host search completed in $SECONDS seconds"

  # loop through each IP and check if google home port is listening
  SECONDS=0
  log.stat "  Scanning for Google devices ..."
  cat $arp_entries | while read -r line ; do
    ip=$(echo $line|awk -F '[()]|at | on ' '{print $2}')
    host=`dig +short +timeout=1 +retry=0 +nostats -x $ip|sed -e 's/\.$//'`
    if [[ $host == "" || $host == *"communications error"* || $host == *"connection timed out"* ]] ; then
      # skip this invalid entry
      continue
    fi
    log.debug "  running 'nc $nc_opt $ip $ghome_port'"
    nc $nc_opt $ip $ghome_port >/dev/null 2>&1
    if [ $? -ne 0 ] ; then 
      # This is not google home device, skip
      continue
    fi
    # This is a ghome device
    log.stat "  $ip ($host) is a google home device." $green
  done
  log.stat "  Google device search completed in $SECONDS seconds"
}

create_info_file() {
  check_ghome_host
  curl -s http://$ghome_host:$ghome_port/setup/eureka_info -o $info_file
  if [ $? -ne 0 ] ; then
    log.error "eureka_info call failed! Likely $ghome_host is not a google home device"
    exit 2
  fi
}

do_info() {
  log.stat "Google Home device details at host: $ghome_host"
  create_info_file
  cat $info_file |jq
}

do_status() {
  log.stat "Google Home device status at host: $ghome_host"
  create_info_file
  log.stat "  Name:   `cat $info_file |jq -r '.name'`"
  log.stat "  IP:     `cat $info_file |jq -r '.ip_address'`"
  log.stat "  SSID:   `cat $info_file |jq -r '.hotspot_bssid'` (likely randomized)"
  log.stat "  Active: `cat $info_file |jq -r '.connected'`"
  local state=`cat $info_file |jq -r '.setup_state'`
  case $state in
    0)
      log.stat "  State:  Factory Default/Out of the box" $red
      ;;
    1)
      log.stat "  State:  Wi-Fi Configuration in Progress" $yellow
      ;;
    2)
      log.stat "  State:  Wi-Fi Connected / Awaiting Association" $yellow
      ;;
    52)
      log.stat "  State:  WAN or DNS failure!" $yellow
      log.stat "  WARNING: This is a dangereous state since the device is wide open!" $red
      log.stat "           Recomendation: turn it off immediately!" $red
      ;;
    60)
      log.stat "  State:  Fully Provisioned and Operational" $green
      ;;
    63)
      log.stat "  State:  Fully Provisioned and Operational (Gen 4 series)" $yellow
      ;;
    *)
      log.stat "  State:  Unknown" $red
      ;;
  esac
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
    c)
      command_name="$OPTARG"
      ;;
    s)
      ghome_host="$OPTARG"
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

# run different wrappes depending on the command requested
case $command_name in
  info)
    do_info
    ;;
  scan)
    if [ -z $iface ] ; then
      get_interface
    fi
    get_my_network
    do_scan
    ;;
  status)
    do_status
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac

