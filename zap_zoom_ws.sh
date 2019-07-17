#!/bin/sh

# zap_zoomws.sh --- simple script to remove zooms hidden webservice from your mac
# Author:  Arul Selvan
# Version: Jul 13, 2019

zoomus_related_junk="ZoomOpener RingCentralOpener TelusMeetingsOpener \
 BTCloudPhoneMeetingsOpener OfficeSuiteHDMeetingOpener \
 ATTVideoMeetingsOpener BizConfOpener HuihuiOpener \
 UMeetingOpener ZhumuOpener ZoomCNOpener"

zoomus_related_junk_dirs="zoomus ringcentralopener telusmeetingsopener \
 btcloudphonemeetingsopener officesuitehdmeetingopener attvideomeetingsopener \
 bizconfopener huihuiopener umeetingopener zhumuopener zoomcnopener"

log_file="/tmp/zap_zoomws.log"
service_port=19421

# check if service is running
pid=`sudo lsof -n -i :$service_port | awk 'NR>1 {print $2;}'`

echo "[INFO] $0 running" >$log_file

if [ -z $pid ] ; then
  echo "[INFO] Doesn't look like zoom hidden webservice is running on your host."
else
  echo "[WARN] found zoom hidden webervice running, attempting to kill..."
  kill -9 $pid
  if [ $? -ne 0 ] ; then
    echo "[ERROR] unable to kill the webservice. pid=$pid, update your zoom client to v4.4.53932.0709"
  else
    echo "[INFO] killed the hidden webservice"
  fi
fi

# zap all the zoom induced junk
echo "[INFO] kill all zoom induced junk ... "
for name in $zoomus_related_junk ; do 
  pkill $name >> $log_file 2>&1
  if [ $? -ne 0 ] ; then
    echo "[INFO] $name is not running" >>$log_file 2>&1
  else
    echo "[ERROR] killed the hidden webservice $name" >> $log_file 2>&1 
  fi
done

echo "[INFO] removing all zoom induced junk ... "
for name in $zoomus_related_junk_dirs ; do
  dir="~/.${name}"
  if [ -d $dir ] ; then
    echo "[WARN] removing $dir" >> $log_file
    rm -rf $dir >> $log_file 2>&1
    touch $dir >> $log_file 2>&1
    chmod 000 $dir >> $log_file 2>&1
  else
    echo "[INFO] $dir not found, skipping" >> $log_file
  fi
done
