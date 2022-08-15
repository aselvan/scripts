#!/bin/bash
#
# openvpn_up.sh --- called by openvpn when vpn is up and is referenced in .ovpn file
#
#
# Author:  Arul Selvan
# Created: Aug 15, 2022
#

# version format YY.MM.DD
version=22.08.15
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
verbose=0
cmdline_args=`printf "%s " $@`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
dns_servers="1.1.1.1 9.9.9.9 8.8.8.8"
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

save_dns() {
  # save existing domain, and two dns
  old_domain=$( (scutil | grep "DomainName : " | sed -e 's/.*DomainName : //')<< EOF
    open
    get State:/Network/Service/${primary_svc}/DNS
    d.show
    quit
EOF
)

  old_dns1=$( (scutil | grep '0 : ' | sed -e 's/\ *0 : //')<< EOF
    open
    get State:/Network/Service/${primary_svc}/DNS
    d.show
    quit
EOF
)

  old_dns2=$( (scutil | grep '1 : ' | sed -e 's/\ *1 : //')<< EOF
    open
    get State:/Network/Service/${primary_svc}/DNS
    d.show
  quit
EOF
)
  # write the current dns and domain to files to be restored when VPN is teared down
  write_log "[STAT]" "saving domain ($old_domain) and dns ($old_dns1 & $old_dns2)"
  echo "$old_domain" > $domain_save_file
  echo "$old_dns1 $old_dns2" > $dns_save_file
}

setup_dns() {
  write_log "[STAT]" "setting up our DNS: '$dns_servers'"
  
  # write our desired DNS (ignore what was pused by VPN server)
  scutil << EOF
    open
    d.init
    d.add ServerAddresses * $dns_servers
    set State:/Network/Service/${primary_svc}/DNS
  quit
EOF
}

# ----------- main -------------
init_log
# as of now just macOS supported. Need to add Linux soon
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

# save the existing DNS config
save_dns

# setup our own DNS
setup_dns
