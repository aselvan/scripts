#!/bin/sh
#
# simple tcpdump script to capture http data on specified network or host (not host) with
# a specific payload_size (OS: macOS or Linux)
#
# Author:  Arul Selvan
# Version: May 24, 2015

# adjust these to your host and network
my_if="eth0"
my_net="192.168.0.0/16"
cap_file="/tmp/http_cap.tcpdump"
payload_size=32

if [ `uname -s` = "Darwin" ] ; then
  my_host=`ipconfig getifaddr $my_if`
else
  my_host=`hostname -i`
fi

if [ -z $my_host ] ; then
  echo "[ERROR] The interface '$my_if' is either not up or don't have IP assigned!"
  exit
fi

# what to capture (all hosts or everything but my host)
if [ ! -z $1 ] && [ $1 = "-a" ] ; then
  include="net $my_net"
else
  include="host not $my_host"
fi

filter="$include and port http and tcp and greater $payload_size"
# uncoment to filter just post data, i.e. P=0x50 O=0x4f S=0x53 T=0x54
#filter="$include and port http and tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x504f5354"

# capture it
sudo tcpdump -vvv -s0 -i $my_if -A -w $cap_file $filter
