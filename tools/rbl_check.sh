#!/usr/bin/env bash
# 
# Script to check if an IP address is in RBL list.
#
# Author: Arul Selvan
# Version History:
#   May 28, 2012 --- Original version
#   Feb 2,  2024 --- Updated to use functions/logger, added user provided list, default egress ip etc.
#

# version format YY.MM.DD
version=23.11.15
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Script to check if an IP address is in RBL list"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:l:vh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# default list of RBLs to check
rbl_list="dnsbl-1.uceprotect.net dnsbl-2.uceprotect.net dnsbl-3.uceprotect.net bl.spamcop.net zen.spamhaus.org dnsbl.sorbs.net bl.tiopan.com cbl.abuseat.org dnsbl.njabl.org b.barracudacentral.org hostkarma.junkemailfilter.com truncate.gbudb.net dnsbl.proxybl.org"
ip=`wget -qO- ifconfig.me/ip`
sed_args="-rn"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -i <ip>   ---> IP to check if it is in RBL list. Default is your egress IP [Default: $ip]
  -l <list> ---> A quoted, space separated RBL list to check the IP
  -v        ---> enable verbose, otherwise just errors are printed
  -h        ---> print usage/help

example: $my_name
example: $my_name -i $ip -l "bl.spamcop.net zen.spamhaus.org dnsbl.sorbs.net"
  
EOF
  exit 0
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
      ip="$OPTARG"
      ;;
    l)
      rbl_list="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ $os_name = "Darwin" ]; then
	sed_args="-En"
fi
reverse_ip=`echo $ip|awk -F. '{print $4"."$3"."$2"."$1;}'`

for rbl in $rbl_list; do
   if [ $verbose -eq 1 ]; then
      status=`host -t a ${reverse_ip}.${rbl}`
   else
      status=`host -t a ${reverse_ip}.${rbl} 2>/dev/null`
   fi
   found=`echo $status |sed $sed_args 's/.*(127.0.[[:digit:]].[[:digit:]]).*/\1/p'` 
   if [ ! -z $found ]; then
      	log.stat "$ip is LISTED on RBL $rbl as $found" $red
   else
      	log.stat "$ip is GOOD on RBL $rbl" 
   fi 
done
