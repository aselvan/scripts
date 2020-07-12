#!/bin/bash
#
# wifi_event_run.sh
#
# This script should be added to wpa_cli on system startup like below to get events
# from the wpa_supplicant when it connects to a new wifi access point or disconnects
# 
# wpa_cli -i wlan0 -B -a <script_path>/wifi_event_run.sh
#
# NOTE: it appears the image raspios-buster-lite does have rc.local systemd unit
#       enabled for compatibility so the above command can be added to /etc/rc.local 
#
#
# Author:  Arul Selvan
# Version: Jul 11, 202
#

# google dns for validating connectivity
gdns=8.8.8.8
pi_hostname=`hostname`
my_ip=""
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
ping_interval=10
ping_attempt=3
ifttt_key_file="/root/.ifttt_key"
ifttt_event_name="pizero"
ifttt_api="https://maker.ifttt.com/trigger/$ifttt_event_name/with/key"

# wpa_supplicant passes these args while invoking this script
iface_name=$1
wifi_status=$2
# other env variables are available at the variable names listed below
# note: they are available only on CONNECT event
# WPA_CTRL_DIR --> contains the absolute path to the ctrl_interface socket
# WPA_ID       --> contains the unique network_id identifier assigned to the active network
# WPA_ID_STR   --> contains the content of the id_str option

write_separator() {
  echo "[INFO] ------------end------------" >> $log_file
}

ping_check() {
  for (( attempt=0; attempt<$ping_attempt; attempt++ )) {
    echo "[INFO] checking for connectivity, attempt #$attempt ..." >> $log_file
    /bin/ping -t30 -c3 -q $gdns >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
      echo "[INFO] we got connectvity!" >> $log_file
      return
    fi
    echo "[INFO] sleeping for $ping_interval sec for another attempt" >> $log_file
    sleep $ping_interval
  }

  echo "[WARN] bummer no connectivity!" >> $log_file
  write_separator
  exit
}

do_ifttt() {
  # if we have ifttt key, send a message
  if [ ! -f $ifttt_key_file ] ; then
    echo "[WARN] no ifttt key provided, skiping." >> $log_file
    return
  else
    ifttt_key=`cat $ifttt_key_file`
  fi

  # post a message to the IFTTT
  timestamp=`date`
  echo "[INFO] sending message via IFTTT!" >> $log_file
  ifttt_endpoint="$ifttt_api/$ifttt_key"
  curl -w "\n" -s -X POST \
    -F "value1=$pi_hostname got internet connectivity at $timestamp" \
    -F "value2=$pi_hostname's public IP is '$my_ip'" \
    -F "value3=$pi_hostname's wifi access point ID: '$WPA_ID_STR'" \
    $ifttt_endpoint >> $log_file 2>&1
}

# connected event. 
# do whatever we need here on connect.
connect_event() {
  echo "[INFO] event: CONNECT on interface '$iface_name'" >> $log_file
  echo "[INFO] WPA_CTRL_DIR = $WPA_CTRL_DIR" >> $log_file
  echo "[INFO] WPA_ID       = $WPA_ID" >> $log_file
  echo "[INFO] WPA_ID_STR   = $WPA_ID_STR" >> $log_file

  # NOTE: it is not clear CONNECTED event is delivered prior to DHCP offer or 
  # post offer. So should we stall few seconds for DHCP offer?
  sleep 5

  # first attempt ping check for 30 sec to see if we have connectivity.
  ping_check

  # since we got internet, phone home?
  my_ip=`dig -p443 +short myip.opendns.com @resolver1.opendns.com`
  url="https://selvans.net/save/saveip.php?host=$pi_hostname&ip=$my_ip"
  echo "[INFO] Publishing to: $url" >> $log_file
  curl -w "\n" -s $url >> $log_file 2>&1

  # send ifttt
  do_ifttt

  # TODO: more stuff to follow later ...
  write_separator
}

disconnect_event() {
  echo "[INFO] event: DISCONNET on interface '$iface_name'" >> $log_file
  write_separator
}

echo "[INFO] `date` wpa_supplicant event received." >> $log_file

case "$wifi_status" in
  CONNECTED)
    connect_event
    ;;
  DISCONNECTED)
    disconnect_event
    ;;
esac

