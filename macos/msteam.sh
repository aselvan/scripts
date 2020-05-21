#!/bin/sh

#
# msteam.sh --- wrapper to avoid ms-team behave like a pig draining power and cpu
#
# Author:  Arul Selvan
# Version: Jan 23, 2020
#

log_file=/tmp/msteam.log

echo "[INFO] Starting MS-Team with gpu disabled."
nice -20 nohup /Applications/Microsoft\ Teams.app/Contents/MacOS/Teams --disable-gpu > $log_file 2>&1 &
