# Install Guide

#### Overview

Simple Firewall script & rules to tighten your macOS with your own firewall. The setup is very 
simple, just follow the instructions below. 

#### Setup
To load the rules on MacOS startup, copy ```pf_rules_simple.conf``` file to ```/etc/pf.anchors/``` and 
edit ```/etc/pf.conf``` file and append the following lines below.

```
#
# ------------------------ Custom firewall rules anchor ------------------------
# Disclaimer: This is a free utility from selvansoft.com provided "as is" without 
# warranty of any kind, express or implied. Use it at your own risk!
#
# Source: https://github.com/aselvan/scripts/tree/master/firewall
#
anchor "com.selvansoft"
load anchor "com.selvansoft" from "/etc/pf.anchors/pf_rules_simple.conf"
```
After the setup above, you now can run ```sudo firewall start``` for rules take effect immediately or 
optionally, you can reboot your mac to validate if the rules survive after boot (they should).

**Note:** Unfortunately, Apple wipes custom rules like these during every MacOS update 
so you have to reapply the above change to ```/etc/pf.conf``` everytime after MacOS update! 
To make it easy, there is a handy script ```firewall_install.sh``` available that can 
be used to make this change instead of manually editing ```/etc/pf.conf```

#### Customization (optional)
Though these firewall rules work just fine *'as is'*, you might want to consider 
customizing it a bit. For my needs, by default, I allow certain things like 
**ssh** within a non-routable local network i.e. *192.168.1.0/24*. You may or may not 
want to do the same so you can modify them to fit your needs. The entries you need 
to revise are in `pf_rules_simple.conf` as shown below.
```
allowed_tcp_ports = "{ 22, 8080, 554, 3689 }"
allowed_udp_ports = "{ 554, 5353 }"
allowed_ips = "{ 192.168.1.0/24 }"
```

#### Advanced Usage (optional)
The ```firewall``` shell script can be used to allow/block specific IPs on the fly. 
This is useful if you want to allow access to a remote IP inbound or outbound temporarily 
for whatever reason. This can be done as shown below.
```
arul@lion$ sudo firewall addip 8.8.8.8
Adding 8.8.8.8 to the dynamic_ips table...
No ALTQ support in kernel
ALTQ related functions disabled
1/1 addresses added.
arul@lion$ 
arul@lion$ sudo firewall showtable
Showing dynamic_ips table...
--- Allowed table: dynamic_ips ----
No ALTQ support in kernel
ALTQ related functions disabled
   8.8.8.8
--- Blocked table: dynamic_blocked_ips ----
No ALTQ support in kernel
ALTQ related functions disabled
pfctl: Table does not exist.
```
Finally, if you are familiar with packet filter rules, you can add more fine controls like rejecting 
everything and stop responding to any specific OS, IP etc. For example, windows devices tend to be 
noisy so you could do this below to shut them off so they dont bother you with nonsense.
```
# we dont want to talk to winblows of any kind :) note: list of os from "sudo pfctl -so"
block in log quick proto tcp from any os "Windows"
```

#### Check status
```
arul@lion$ sudo firewall status
Password:
Listing firewall rules ...
--- Global rules ---
No ALTQ support in kernel
ALTQ related functions disabled
scrub-anchor "com.apple/*" all fragment reassemble
anchor "com.apple/*" all
anchor "com.selvansoft" all
--- Anchor: com.selvansoft rules ---
No ALTQ support in kernel
ALTQ related functions disabled
block return log all
block return out quick from any to <dynamic_blocked_ips>
pass out quick all flags S/SA keep state
pass in proto udp from any to any port = 53 keep state
pass in proto udp from any to any port = 67 keep state
pass in proto udp from any to any port = 68 keep state
pass in proto udp from any to any port = 123 keep state
pass in inet proto icmp all icmp-type echorep keep state
pass in inet proto icmp all icmp-type unreach keep state
pass in inet proto icmp all icmp-type echoreq keep state
pass in inet proto icmp all icmp-type timex keep state
pass in inet proto tcp from 192.168.1.0/24 to any port = 22 flags S/SA keep state
pass in inet proto tcp from 192.168.1.0/24 to any port = 8080 flags S/SA keep state
pass in inet proto tcp from 192.168.1.0/24 to any port = 554 flags S/SA keep state
pass in inet proto tcp from 192.168.1.0/24 to any port = 3689 flags S/SA keep state
pass in inet proto udp from 192.168.1.0/24 to any port = 554 keep state
pass in inet proto udp from 192.168.1.0/24 to any port = 5353 keep state
pass in proto tcp from <dynamic_ips> to any port = 22 flags S/SA keep state
pass in proto tcp from <dynamic_ips> to any port = 8080 flags S/SA keep state
pass in proto tcp from <dynamic_ips> to any port = 554 flags S/SA keep state
pass in proto tcp from <dynamic_ips> to any port = 3689 flags S/SA keep state
pass in proto udp from <dynamic_ips> to any port = 554 keep state
pass in proto udp from <dynamic_ips> to any port = 5353 keep state
--- Dynamic table list (if any) ---
No ALTQ support in kernel
ALTQ related functions disabled
No ALTQ support in kernel
ALTQ related functions disabled
pfctl: Table does not exist.
```

