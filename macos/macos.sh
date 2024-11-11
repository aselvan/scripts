#!/usr/bin/env bash
#
# macos.sh --- Misl tools for macOS all in one place
#
#
# Author:  Arul Selvan
# Created: Aug 25, 2024
#
# Version History:
#   Aug 25, 2024 --- Original version
#   Nov 11, 2024 --- Added showipexternal command, show interface on showip command
#

# version format YY.MM.DD
version=2024.10.11
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl tools for macOS all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"

# commandline options
options="c:i:n:avh?"

command_name=""
supported_commands="ip|lanip|wanip|mac|dhcp|scannetwork|mem|vmstat|cpu"
iface=""
my_net="192.168.1.0/24"
my_ip=""

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>   ---> command to run [see supported commands below]
  -i <interface> ---> network interface to use [Default: $iface]
  -n <network>   ---> CIDR address to scan for 'shownetwork' command [Default: $my_net]
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

Supported commands: $supported_commands
example: $my_name -c ipexternal

  
EOF
  exit 0
}

# detect active, IP assigned interface, first one matchign will be used
function get_interface() {
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

function showmac() {
  mac_addr=`ifconfig $iface | grep ether| awk '{print $2;}'`
  log.stat "\tMAC address of $iface is: $mac_addr" $green
}

function showdhcp() {
  log.stat "`ipconfig getpacket $iface`"
}

function scannetwork() {
  nmap --host-timeout 10 -T5 $my_net >/dev/null 2>&1
  arp -an|egrep -v 'incomplete|ff:ff:ff:ff|169.254|224.|239.|.255)'> $arp_entries

  cat $arp_entries | while read -r line ; do
    ip=$(echo $line|awk -F '[()]|at | on ' '{print $2}')
    mac=$(echo $line|awk -F '[()]|at | on ' '{print $4}')
    host=`dig +short -x $ip|sed -e 's/\.$//'`
    if [ -z "$host" ] ; then
      host="N/A"
    fi
    log.stat "  $ip\t $host\t # macaddress: $mac" $green
  done
}

showmem() {
  hwmemsize=$(sysctl -n hw.memsize)
  ramsize=$(expr $hwmemsize / $((1024**3)))
  free_percent=$(memory_pressure|grep percentage|awk '{print $5;}')
  log.stat "\tPhysical Memory: ${ramsize}GB" $green
  log.stat "\tFree Memory    : ${free_percent}" $green
}

showvmstat() {
  log.stat "`vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'`" $green

}

showcpu() {
  log.stat "\tVendor: `sysctl -a machdep.cpu.vendor|awk -F: '{print $2}'`"  $green
  log.stat "\tBrand:  `sysctl -a machdep.cpu.brand_string|awk -F: '{print $2}'`" $green
  log.stat "\tFamily: `sysctl -a machdep.cpu.extfamily|awk -F: '{print $2}'`" $green
  log.stat "\tModel:  `sysctl -a machdep.cpu.model|awk -F: '{print $2}'`" $green
  log.stat "\t#cores: `sysctl -a machdep.cpu.core_count|awk -F: '{print $2}'`" $green
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
    n)
      network="$OPTARG"
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

# determine the interface if one not provided.
if [ -z "$iface" ] ; then
  get_interface
fi

my_ip=`ipconfig getifaddr $iface`
my_net=`echo $my_ip |awk -F. '{print $1"."$2"."$3".0/24"; }'` 

case $command_name in 
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
  scannetwork)
    log.stat "Scanning network $my_net using interface $iface ... [note: make sure $iface is correct]"
    scannetwork
    ;;
  mem)
    showmem
    ;;
  cpu)
    showcpu
    ;;
  vmstat)
    showvmstat   
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
