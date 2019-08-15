#!/bin/sh
# 
# simple script to check if an IP address is in RBL list.
#
# Author:  Arul Selvan
# Version: May 28, 2012

#rbl_list="bl.spamcop.net zen.spamhaus.org dnsbl.sorbs.net bl.tiopan.com cbl.abuseat.org blackholes.five-ten-sg.com dnsbl.njabl.org"
rbl_list="dnsbl-1.uceprotect.net dnsbl-2.uceprotect.net dnsbl-3.uceprotect.net bl.spamcop.net zen.spamhaus.org dnsbl.sorbs.net bl.tiopan.com cbl.abuseat.org dnsbl.njabl.org b.barracudacentral.org hostkarma.junkemailfilter.com truncate.gbudb.net dnsbl.proxybl.org"
ip=
debug=0
sed_args="-rn"

usage() {
    echo "$0 --ip <ipaddress_to_check>"
    exit
}

if [ `uname -s` = "Darwin" ]; then
	sed_args="-En"
fi

while [ "$1" ]  
do
    if [ "$1" = "--ip" ]; then
        shift 1
        ip=$1
        shift 1
    elif [ "$1" = "--debug" ]; then
        shift 1
        debug=1 
    elif [ "$1" = "--help" ]; then
        usage
    else 
        usage
    fi 
done
if [ -z $ip ]; then
    echo "missing argument"
    usage
fi

reverse_ip=`echo $ip|awk -F. '{print $4"."$3"."$2"."$1;}'`


for rbl in $rbl_list; do
   if [ $debug -eq 1 ]; then
      status=`host -t a ${reverse_ip}.${rbl}`
   else
      status=`host -t a ${reverse_ip}.${rbl} 2>/dev/null`
   fi
   found=`echo $status |sed $sed_args 's/.*(127.0.[[:digit:]].[[:digit:]]).*/\1/p'` 
   if [ ! -z $found ]; then
      	echo "$ip is LISTED on RBL $rbl as $found"
   else
      	echo "$ip is GOOD on RBL $rbl" 
   fi 
done
