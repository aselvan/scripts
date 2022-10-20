#!/bin/bash
#
# openvpn_down.sh --- called by openVPN when VPN is teared down.
#
# Purpose: When you run openVPN (under the hood, many VPN vendor software run openVPN), you 
#          may end up going to your original resolver leaking your DNS queries. This script
#          works along with openvpn_up.sh to set/reset the DNS servers. It will be called 
#          by openVPN after tear down of VPN tunnel to restore your original DNS. This 
#          script is referenced in openVPN config file: vpnsecure.ovpn
#
# Note: As of now, this script only works on macOS, need to update to work on Linux later.
#
# See: vpnsecure.ovpn 
# See: openvpn_up.sh 
#
#
# Author:  Arul Selvan
# Created: Aug 15, 2022
#

# version format YY.MM.DD
version=22.10.20
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
verbose=0
cmdline_args=`printf "%s " $@`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
dns_save_file="/tmp/openvpn_dns_save.log"
domain_save_file="/tmp/openvpn_domain_save.log"
primary_svc=""

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

write_log() {
  local msg_type=$1
  local msg=$2

  # log info type only when verbose flag is set
  if [ "$msg_type" == "[INFO]" ] && [ $verbose -eq 0 ] ; then
    return
  fi

  echo "$msg_type $msg" >> $log_file
}
init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "[STAT]" "$my_version: starting at `date +'%m/%d/%y %r'` ..."
  write_log "[STAT]" "cmdline: $cmdline_args"  
}

restore_dns() {
  
  if [ ! -e $dns_save_file ] ; then
    write_log "[ERROR]" "missing save DNS file ($dns_save_file)"
    return
  fi

  write_log "[STAT]" "restoring saved DNS '`cat $dns_save_file`'"

  # restore dns and domain
  scutil << EOF
    open
    d.init
    d.add ServerAddresses * `cat $dns_save_file`
    d.add DomainName `cat $domain_save_file`
    set State:/Network/Service/${primary_svc}/DNS
  quit
EOF
}

# ----------- main -------------
init_log
# as of now just macOS supported. Need to add Linux soon.
if [ $os_name != "Darwin" ] ; then
  write_log "[WARN] this os '$os_name' is currently not supported!"
  exit 1
fi

# find the primiary svc
primary_svc=$( (scutil | grep PrimaryService | sed -e 's/.*PrimaryService : //')<< EOF
  open
  get State:/Network/Global/IPv4
  d.show
  quit
EOF
)

# restored saved dns and domain name when VPN is
restore_dns

