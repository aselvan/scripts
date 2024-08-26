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
#

# version format YY.MM.DD
version=24.0825
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
supported_commands="showip|showmac|showdhcp|scannetwork|showmem|showvmstat"
iface="en0"
my_net="192.168.1.0/24"
my_ip=""

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>   ---> command to run
  -i <interface> ---> network interface to use [Default: $iface]
  -n <network>   ---> CIDR address to scan for 'shownetwork' command [Default: $my_net]
  -a             ---> show all details
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

Supported commands: $supported_commands
example: $my_name -c showip

  
EOF
  exit 0
}

function showmac() {
  mac_addr=`ifconfig $iface | grep ether| awk '{print $2;}'`
  log.stat "MAC address of $iface is: $mac_addr"
}

function showdhcp() {
  log.stat "`ipconfig getpacket $iface`"
}

function scannetwork() {
  nmap --host-timeout 3 -T5 $my_net >/dev/null 2>&1
  arp -an|egrep -v 'incomplete|ff:ff:ff:ff|169.254|224.|239.|.255)'> $arp_entries

  cat $arp_entries | while read -r line ; do
    ip=$(echo $line|awk -F '[()]|at | on ' '{print $2}')
    mac=$(echo $line|awk -F '[()]|at | on ' '{print $4}')
    host=`dig +short -x $ip|sed -e 's/\.$//'`
    if [ -z "$host" ] ; then
      host="N/A"
    fi
    log.stat "$ip\t $host\t # macaddress: $mac"
  done
}

showmem() {
  hwmemsize=$(sysctl -n hw.memsize)
  ramsize=$(expr $hwmemsize / $((1024**3)))
  free_percent=$(memory_pressure|grep percentage|awk '{print $5;}')
  log.stat "Physical Memory: ${ramsize}GB" $green
  log.stat "Free Memory    : ${free_percent}" $green
}

showvmstat() {
  log.stat "`vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'`" $green

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

my_ip=`ipconfig getifaddr $iface`
my_net=`echo $my_ip |awk -F. '{print $1"."$2"."$3".0/24"; }'` 

case $command_name in 
  showmac)
    showmac
    ;;
  showip)
    log.stat "My IP: $my_ip"
    ;;
  showdhcp)
    showdhcp
    ;;
  scannetwork)
    scannetwork
    ;;
  showmem)
    showmem
    ;;
  showvmstat)
    showvmstat   
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
