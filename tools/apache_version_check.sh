#!/bin/bash
#
# apache_version_check.sh --- quick and dirty script to check apache version.
#
# Author:  Arul Selvan
# version: Oct 6, 2021
#

# fill in your desired IP/host and port where apache might be running.
servers="192.168.1.1 192.168.1.2 192.168.1.3"
port=8080

for s in $servers ; do
  echo "Checking server: $s:$port"
  echo -e "\tVersion: `curl -m2 -vs $s:$port 2>&1|awk '/Server:/ {print $3;}'`"
done
