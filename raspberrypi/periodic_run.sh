#!/bin/bash
#
# periodic_run.sh 
#
# This script is setup as cronjob to run every 5 minutes. It should try and 
# complete under 5 minutes and if it takes longer, the cron interval should 
# be adjusted; but cronjob is protected from mulitple invocation anyways.
#
# Note: copy this script to /root/scripts or other place refered in crontab path
#
# Author:  Arul Selvan
# Version: Jul 4, 2020
#

# current version: YY.MM.DD
version=22.07.17

# google dns for validating connectivity
gdns=8.8.8.8
my_name="`basename $0` v$version"
log_file="/var/log/$(echo $my_name|cut -d. -f1).log"
home_public_ip=`dig +short selvans.net @$gdns`
publish_ip_url_file="/root/.publish_ip_url"


pi_is_home() {
  echo "[INFO] PI is home!" >> $log_file
  
  # TODO: copy the tesla dashcam data here... (need to figure out how often we do this)

  # update our git to get all the code with new release so pi is updated with newly released code
  (cd /root/scripts; /usr/bin/git pull 2>&1 >> $log_file)
}

pi_is_not_home() {
  
  echo "[INFO] PI somewhere other than home!" >> $log_file
  
  # TODO: do any other stuff we want here.
}

#  ---------- main ---------------
echo "[INFO] $my_name starting at `date`..." >> $log_file

# first check if we got connectivity.
/bin/ping -t30 -c3 -q $gdns >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[WARN] We dont have connectivity. force dhcpd? or force wpa_supplicant to try again?" >> $log_file
  # for now, exit; will figureout how to force wlan to reconnect.
  exit
fi

# we got connectivity, see if we are at home (NOTE: reads the router IP from env variable)
if [ -z "${HOME_PUBLIC_IP}" ] ; then
  echo "[INFO] HOME_PUBLIC_IP not set, assuming this is us (selvans.net) " >> $log_file
else
  home_public_ip=${HOME_PUBLIC_IP}
fi

# find pi's egress IP
my_ip=`dig +short myip.opendns.com @resolver1.opendns.com`
my_ip=`curl -s ifconfig.me/ip`
echo "[INFO] `hostname` public IP is: $my_ip" >> $log_file

if [ ${home_public_ip} = ${my_ip} ] ; then
  pi_is_home
else
  pi_is_not_home
fi

# save the last location info
if [ -f $HOME/last_location.txt ] && [ -f $publish_ip_url_file ] ; then
  latlon_url="https://www.google.com/maps?q=`cat $HOME/last_location.txt`"
  url="$publish_ip_url?host=tesla&ip=$latlon_url"
  echo "[INFO] Publishing to: $url" >> $log_file
  curl -w "\n" -s $url >> $log_file 2>&1
fi

echo "[INFO] nothing more for now, exiting" >> $log_file

# TODO: more stuff later ...

