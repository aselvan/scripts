#!/bin/sh
#
# IP tables rules to fake failure on every 3rd req. 
# 
# Basically, forward 80 to an external host based on the state "NEW" connection
# and forward the 3rd "NEW" connection to local host (assuming there is no 80 
# service) therefore it will fail. Also, log it.
# 
# Author:  Arul Selvan
# Version: Jun 2017
#
#sysctl net.ipv4.ip_forward=1

# change as needed
PORT=80
REAL_DEST=192.168.1.11
INTERFACE=wlan0

echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -p tcp --dport $PORT -j MASQUERADE
iptables -t nat -A PREROUTING -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -m statistic --mode nth --every 3 --packet 0 -j DNAT --to-destination $REAL_DEST:$PORT
iptables -t nat -A PREROUTING -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -m statistic --mode nth --every 3 --packet 1 -j DNAT --to-destination $REAL_DEST:$PORT
iptables -t nat -A PREROUTING -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -m statistic --mode nth --every 3 --packet 2 -j REDIRECT --to-ports $PORT
iptables -A INPUT -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -j LOG --log-prefix "[DROP'ing $PORT]: " --log-level 2
iptables -A INPUT -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -j REJECT

