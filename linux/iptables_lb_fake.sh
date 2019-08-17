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
REAL_DEST=10.34.210.5
INTERFACE=eth0

echo "1" > /proc/sys/net/ipv4/ip_forward
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t nat -A POSTROUTING -p tcp --dport $PORT -j MASQUERADE
/sbin/iptables -t nat -A PREROUTING -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -m statistic --mode nth --every 3 --packet 0 -j DNAT --to-destination $REAL_DEST:$PORT
/sbin/iptables -t nat -A PREROUTING -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -m statistic --mode nth --every 3 --packet 1 -j DNAT --to-destination $REAL_DEST:$PORT
/sbin/iptables -t nat -A PREROUTING -p tcp -i $INTERFACE --dport $PORT -m state --state NEW -m statistic --mode nth --every 3 --packet 2 -j REDIRECT --to-ports $PORT
/sbin/iptables -A INPUT -p tcp -i $INTERFACE --dport $PORT -j LOG --log-prefix "[DROP $PORT]: " --log-level 2
#/sbin/iptables -A INPUT -p tcp -i $INTERFACE --dport $PORT -j REJECT
