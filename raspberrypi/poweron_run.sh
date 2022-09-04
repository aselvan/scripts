#!/bin/bash
#
# poweron_run.sh 
#
# Power on script i.e. when tesla wakes up the hub is powered so our PI 
# should be booting. This script make use of this to do anthying we want
# to do when PI is powered on
#
# Note: copy this script to /root/scripts or other place refered in crontab path with following 
#
# The following is an example crontab for running this script on PI booting
#########################################################################
#
# PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# IFTTT_KEY=<your_IFTTT_KEY>
# HOME_PUBLIC_IP=<your_HOME_PUBLIC_IP>
# EXTERNAL_SSH_PORT=<port you opened for ssh into pi>
# EXTERNAL_IP_LIST=<list of any external IP to allow ssh into pi>
# #Note: need to send to background to let PI continue to boot
# 
# @reboot /root/scripts/raspberrypi/poweron_run.sh >/dev/null 2>&1 &
#
#########################################################################
#
# Author:  Arul Selvan
# Created: Jul 4, 2020

# current version: YY.MM.DD
version=22.07.17

# google dns for validating connectivity
gdns=8.8.8.8
my_name="`basename $0` v$version"
log_file="/var/log/$(echo $my_name|cut -d. -f1).log"
# should take this also as env option later.
ifttt_event_name="pizero"
ifttt_api="https://maker.ifttt.com/trigger/$ifttt_event_name/with/key"
ssh_port=22
publish_ip_url_file="/root/.publish_ip_url"
ping_interval=10
ping_attempt=3
my_ip="N/A"
pi_hostname=`hostname`
wifi_event_script="/root/scripts/raspberrypi/wifi_event_run.sh"
gps_echo_script="/root/scripts/tools/gps_echo.py"
wifi_interface="wlan0"


ping_check() {
  for (( attempt=0; attempt<$ping_attempt; attempt++ )) {
    echo "[INFO] checking for connectivity, attempt #$attempt ..." >> $log_file
    ping -t30 -c3 -q $gdns >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      echo "[INFO] we got connectvity!" >> $log_file
      return
    fi
    echo "[INFO] sleeping for $ping_interval sec for another attempt" >> $log_file
    sleep $ping_interval
  }

  echo "[WARN] We dont have connectivity. force dhcpd? or force wpa_supplicant to try again?" >> $log_file
  # for now, exit; will figureout how to force wlan to reconnect.
  exit
}


publish_ip() {
  # get publish_ip_url; NOTE: URL should take host & ip as query parameter
  if [ ! -f $publish_ip_url_file ] ; then
    echo "[WARN] no publish IP url provided, skiping." >> $log_file
    return
  else
    publish_ip_url=`cat $publish_ip_url_file`
  fi

  echo "[INFO] publish our IP using $publish_ip_url" >> $log_file

  # find pi's egress IP
  my_ip=`curl -s ifconfig.me/ip`
  url="$publish_ip_url?host=$pi_hostname&ip=$my_ip"
  echo "[INFO] Publishing to: $url" >> $log_file
  curl -w "\n" -s $url >> $log_file 2>&1
}

#  ---------- main ---------------
echo "[INFO] `date`: $my_name starting..." >> $log_file

# check if we need to punch hole for ssh access from external hosts
# assumes ufw is setup already and activated.
if [ ! -z "${EXTERNAL_IP_LIST}" ] ; then
  echo "[INFO] checking and/or enabling external hosts for ssh access" >> $log_file
  if [ -z "${EXTERNAL_SSH_PORT}" ]; then
    echo "[WARN] using $ssh_port for ssh port, highly recomended to use a different port!" >> $log_file
  else
    ssh_port=${EXTERNAL_SSH_PORT}
    echo "[INFO] using $ssh_port for ssh port!" >> $log_file
  fi
  # go through the list
  external_ip_list=${EXTERNAL_IP_LIST}
  for external_ip in $external_ip_list ; do
    echo "[INFO] checking and/or adding $external_ip" >> $log_file
    ufw status |grep $external_ip >> $log_file 2>&1
    if [ $? -eq 0 ] ; then
      echo "[INFO] the external IP ($external_ip) already in firewall allowed list" >> $log_file
      continue
    else
      echo "[INFO] adding external IP ($external_ip) to firewall allowed list" >> $log_file
      ufw allow from $external_ip to any port $ssh_port >> $log_file 2>&1
      ufw status |grep $external_ip >> $log_file 2>&1
    fi
  done
else
  echo "[WARN] no EXTERNAL_IP_LIST env variable set, skiping firewall access setup." >> $log_file
fi


# check if we have IFTTT creds are provided via env variable
if [ -z "${IFTTT_KEY}" ] ; then
  echo "[ERROR] no IFTTT_KEY no message is sent via IFTTT!" >> $log_file
  exit
fi

# ensure we have connectivity before proceeding fruther.
ping_check

# since we got internet, phone home?
publish_ip

# note: raspberrypi does not have RT clock. Not sure the fakehw clock is initialized at 
# this stage in boot sequence, so just query and see if it makes sense to even attempt 
# to get the timestamp
# query for presense of time server
time_server=`timedatectl show-timesync -p ServerName --value`
if [ -z $time_server ] ; then
  timestamp="N/A"
else
  timestamp=`date`
fi

# find location
if [ -e $gps_echo_script ] ; then
  my_latlon="https://www.google.com/maps?q=`$gps_echo_script`"
  if [ $my_latlon = "0.0,0.0" ] ; then
    my_latlon="https://www.google.com/maps?q=`curl -s ipinfo.io/loc`"
    echo "[INFO] current $pi_hostname location (GPS device failed, IP based): $my_latlon" >> $log_file
  else
    echo "[INFO] current $pi_hostname location (GPS device based): $my_latlon" >> $log_file
  fi
else
  my_latlon="https://www.google.com/maps?q=`curl -s ipinfo.io/loc`"
  echo "[INFO] current $pi_hostname location (IP based): $my_latlon" >> $log_file
fi

# post a message to the IFTTT
echo "[INFO] sending message via IFTTT!" >> $log_file
ifttt_endpoint="$ifttt_api/$IFTTT_KEY"

curl -w "\n" -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"value1\":\"${my_name}: $pi_hostname public IP is: $my_ip\", \"value2\":\"$pi_hostname is/was powered on at $timestamp\",\"value3\":\"$my_latlon\"}" \
  $ifttt_endpoint >> $log_file 2>&1

# register handler for WIFI CONNECTED or DISCONNECTED events
if [ -e $wifi_event_script ] ; then
  echo "[INFO] registering for WIFI events on device $wifi_interface using $wifi_event_script ..." >> $log_file
  wpa_cli -i $wifi_interface -B -a $wifi_event_script >> $log_file 2>&1
fi

echo "[INFO] nothing more for now, exiting" >> $log_file

# TODO: more stuff later ...
