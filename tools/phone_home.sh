#!/bin/bash
#
# phone_home.sh --- log/email current public IP to home
#
# Author  : Arul Selvan
# Version : Nov 10, 2011

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=11.11.10
my_name=`basename $0`
my_version="$my_name v$version"
os_name=`uname -s`
my_hostname=`hostname`
options="e:u:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
saveip_url=""
email_address=""
email_subject="External IP changed: $my_hostname"
ip_info_file="$HOME/.ip_info.txt"
ip_file="$HOME/.public_ip.txt"
ifconfig_url="https://ifconfig.me/ip"
old_ip=""
new_ip=""

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -u <url>   ---> The URL should take host & ip as query parameter. example: https://example.com?host=xxx&ip=xxx"
  echo "  -e <email> ---> optional: send IP via e-mail in addition to posting to URL argument"
  echo "  -h         ---> help/usage"
  echo ""
  echo "ex: $my_name -e myemail@sample.com -u https://sample.com/saveip"
  echo ""
  exit 0
}

# ----------  main --------------
# parse commandline options
while getopts $options opt; do
  case $opt in
    e)
      email_address="$OPTARG"
      ;;
    u)
      saveip_url="$OPTARG"
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -f $log_file ] ; then
  rm $log_file
fi
echo "[INFO] $my_version" > $log_file

if [ -z $saveip_url ] ; then
  echo "[ERROR] required argument missing!" 
  usage
fi

if [ ! -f $ip_file ] ; then
  echo -n `curl -fs $ifconfig_url` > $ip_file
  old_ip=`cat $ip_file`
  new_ip=$old_ip
else
  old_ip=`cat $ip_file`
  new_ip=`curl -fs $ifconfig_url`
fi

if [ -z "$new_ip" ]; then
  # if new ip is null just leave
  echo "ERROR getting public IP from $ifconfig_url ... exiting." >> $log_file
  exit
elif [ "$old_ip" = "$new_ip" ] ; then
  echo "IP did not change since last check, exiting." >> $log_file
  exit
fi

# record external and internal ip on all interfaces to file to be e-mailed.
echo "Date: `date`" > $ip_info_file
echo "IP changed: new external IP is \"$new_ip\" and the old one was $old_ip" >> $ip_info_file

# get all the internal interface list and find the internal IP
ifaces=`ifconfig -a | sed -E 's/[[:space:]:].*//;/^$/d'`
for iface in $ifaces ;  do
  int_ip=`ipconfig getifaddr $iface`
  if [ ! -z $int_ip ] ; then
    echo "Internal [interface:IP]: $iface: $int_ip" >> $log_file
    echo "Internal [interface:IP]: $iface: $int_ip" >> $ip_info_file
  fi
done

if [ ! -z $email_address ] ; then
  echo "sending email to $email_address" >> $log_file
  cat $ip_info_file |mail -s "$email_subject" $email_address
fi

# finally, save new IP
echo "Saving new IP: $new_ip" >> $log_file
echo $new_ip > $ip_file

# now post the ip to the saveip_url
echo "Posting to URL: ${saveip_url}?host=${my_hostname}&ip=${new_ip}" >> $log_file
curl -fs "${saveip_url}?host=${my_hostname}&ip=${new_ip}" >/dev/null 2>&1

echo "Done" >> $log_file
