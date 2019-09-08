#!/bin/sh
# 
# zap_zoomws.sh --- simple script to remove zooms hidden webservice from your mac
# Author:  Arul Selvan
# Version: Jul 13, 2019
#
# Disclaimer: use it at your own risk, I am not responsible for any damage.

zoomus_related_junk="ZoomOpener RingCentralOpener TelusMeetingsOpener \
 BTCloudPhoneMeetingsOpener OfficeSuiteHDMeetingOpener \
 ATTVideoMeetingsOpener BizConfOpener HuihuiOpener \
 UMeetingOpener ZhumuOpener ZoomCNOpener"

zoomus_related_junk_dirs="zoomus ringcentralopener telusmeetingsopener \
 btcloudphonemeetingsopener officesuitehdmeetingopener attvideomeetingsopener \
 bizconfopener huihuiopener umeetingopener zhumuopener zoomcnopener"

log_file="/tmp/zap_zoomws.log"
service_port=19421
service_port_range="19400-19500"

# get a list of any of the zoom junk or its variants if they are running.
pids=`sudo lsof -nP +c 15 -sTCP:LISTEN -i tcp:$service_port_range|awk 'NR>1 {print $2;}'|uniq`;

echo "[INFO] zap_zoomws.sh starting" >$log_file

if [ ! -z "$pids" ] ; then
  # attempt to directly kill running zoom induced junk
  echo "[INFO] kill runnning zoom variat junk by pid ... " | tee -a $log_file  
  for pid in $pids ; do
    kill -9 $pid
    if [ $? -ne 0 ] ; then
      echo "[ERROR] unable to kill pid=$pid, check and manually remove!" | tee -a $log_file
    else
      echo "[INFO] killed the web server at pid=$pid" | tee -a $log_file
    fi
  done

  # attempt to kill all the zoom induced junk apps by name
  echo "[INFO] kill running zoom variant junk by name " | tee -a $log_file
  for name in $zoomus_related_junk ; do 
    pkill $name >> $log_file 2>&1
    if [ $? -ne 0 ] ; then
      echo "[INFO] $name is not running" >>$log_file 2>&1
    else
      echo "[ERROR] killed the hidden webservice $name" >> $log_file 2>&1 
    fi
  done
else
  echo "[INFO] Doesn't look like zoom & other zoom branded services are currently running."|tee -a $log_file
fi


echo "[INFO] removing zoom variant installers to prevent future silent installs." | tee -a $log_file
for name in $zoomus_related_junk_dirs ; do
  dir="~/.${name}"
  if [ -d $dir ] ; then
    echo "[WARN] removing $dir" | tee -a $log_file
    rm -rf $dir >> $log_file 2>&1
    touch $dir >> $log_file 2>&1
    chmod 000 $dir >> $log_file 2>&1
  else
    echo "[INFO] $dir not found, skipping" >> $log_file
  fi
done

