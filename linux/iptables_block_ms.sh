#
# iptables_rules.sh
#
# simple iptables rule to block microsoft CIDR 134.170.0.0/16
#
# Author:  Arul Selvan
# Version: jun 7, 2014
#
iptables -F
iptables -A INPUT  -s 134.170.0.0/16  -j DROP
iptables -A OUTPUT -d 134.170.0.0/16  -j DROP

iptables -L -n -v
