#!/bin/sh

# zap_zoomws.sh --- simple script to remove zooms hidden webservice from your mac
# Author:  Arul Selvan
# Version: Jul 13, 2019

service_port=19421
pid=`sudo lsof -n -i :$service_port | awk 'NR>1 {print $2;}'`

if [ -z $pid ] ; then
  echo "[INFO] Doesn't look like zoom hidden webservice is running on your host."
  exit
fi

echo "[WARN] found zoom hidden webervice running, attempting to kill..."
kill -9 $pid
if [ $? -ne 0 ] ; then
  echo "[ERROR] unable to kill the webservice. pid=$pid, update your zoom client to v4.4.53932.0709"
else
  echo "[INFO] killed the hidden webservice"
fi

# not needed but do it anyway
pkill "ZoomOpener"

# wipe the trace of user preference. Actually, need to touch this to be readonly.
rm -rf ~/.zoomus
touch ~/.zoomus;
chmod 000 ~/.zoomus;
