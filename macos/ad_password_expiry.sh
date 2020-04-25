#/bin/sh
#
# ad_password_expiry.sh --- check the AD password expiry date
#
# This script can be used in script to check exit code which will be the # of days 
# leftin the password expiry except 0 which is an error; this is ass backwards 
# behavior of any unix app or script but who cares?
#
# Author:  Arul Selvan
# Version: Apr 25, 2020
#

# commandline arguments
options_list="u:d:h"

# works with user login or elevated
user=`who -m | awk '{print $1;}'`
# note: case sensitive!
domain_prefix="RRI"

usage() {
	echo "Usage: $0 [-u ad_user_nanme] [-d domain_prefix] "
  echo "   ex: $0 -u arul -d selvans.net"
	exit 0
}

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    u)
      user=$OPTARG
      ;;
    d)
      domain_prefix=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

echo "[INFO] checking AD password expiry for '$user' ... "

# Perform 2 checks to determine if this mac is part of an AD domain
# 1. check if this mac is bound to an AD domain (could be offline or not on VPN)
ad_domain=`dsconfigad -show | awk '/Active Directory Domain/{print $NF}'`
if [ -z $ad_domain ] ; then
  echo "[ERROR] this device is not bound to any AD domain"
  exit 0
else
  echo "[INFO] device is bound to $ad_domain"
fi

# 2. check if DNS query returns a LDAP SRV record, inidcation of AD server available for further queries
host -t srv _ldap._tcp.$ad_domain >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[ERROR] no LDP srv records, this device may be bound to AD but offline, try connecting to VPN"
  exit 0
fi

# update domain path with commandline option
domain_path="/Active Directory/$domain_prefix/All Domains"

# get the password expiry date from AD
echo "[INFO] querying AD with '$domain_path' for '$user'"
expiry_time=`dscl "$domain_path" -read Users/$user msDS-UserPasswordExpiryTimeComputed| awk '/dsAttrTypeNative/{print $NF}'`
if [ -z $expiry_time ] ; then
  echo "[ERROR] empty response while qurying AD server, code=$?"
  exit 0
fi

# convert unix seconds
expiry_time_secs=$(echo "($expiry_time/10000000)-11644473600" | /usr/bin/bc)

# construct date it expires
expiry_date=$(date -r $expiry_time_secs)

# subtract expiry_time_sec from today_sec and convert to calculate
# number of days left for password expiry
today_sec=$(/bin/date +%s)
num_days_left=$(echo "($expiry_time_secs - $today_sec)/60/60/24" | /usr/bin/bc)

echo "[INFO] $user, your password will expire in $num_days_left days on/after '$expiry_date'"

# exit w/ number of days left (may not be good idea if its more than 255 but no AD server will allow that big)
exit $num_days_left
