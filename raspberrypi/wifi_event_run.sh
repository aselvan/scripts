#!/bin/bash
#
# wifi_event_run.sh
#
# This script should be added to wpa_cli on system startup like below to get events
# from the wpa_supplicant when it connects to a new wifi access point or disconnects
# 
# wpa_cli -i wlan0 -B -a <script_path>/wpa_supplicant_event.sh
#
# NOTE: it appears the image raspios-buster-lite does have rc.local systemd unit
#       enabled for compatibility so the above command can be added to /etc/rc.local 
#
#
# Author:  Arul Selvan
# Version: Jul 11, 202
#

pi_hostname=`hostname`
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

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

# connected event. 
# do whatever we need here on connect.
connect_event() {
  echo "[INFO] event: CONNECT on interface '$iface_name'" >> $log_file
  echo "[INFO] WPA_CTRL_DIR = $WPA_CTRL_DIR" >> $log_file
  echo "[INFO] WPA_ID       = $WPA_ID" >> $log_file
  echo "[INFO] WPA_ID_STR   = $WPA_ID_STR" >> $log_file

  # should we stall few seconds for DHCP offer?
  # NOTE: it is not clear CONNECTED event is delivered prior to DHCP offer or post offer
  sleep 5

  # first check if we really got connectivity.
  /bin/ping -t30 -c3 -q $gdns >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[WARN] bummer no connectivity!" >> $log_file
    write_separator
    exit
  fi

  # since we got internet, phone home?
  my_ip=`dig -p443 +short myip.opendns.com @resolver1.opendns.com`
  url="https://selvans.net/save/saveip.php?host=$pi_hostname&ip=$my_ip"
  echo "[INFO] Publishing to: $url" >> $log_file
  curl -s $url >> $log_file 2>&1

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

