#!/bin/sh

#
# msteam.sh --- wrapper to avoid ms-team behave like a pig draining power and cpu
#
# Author:  Arul Selvan
# Version: Jan 23, 2020
#

echo "[INFO] Starting MS-Team with gpu disabled."
nohup /Applications/Microsoft\ Teams.app/Contents/MacOS/Teams --disable-gpu &
