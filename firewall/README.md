# Install Guide

#### Overview
Simple Firewall script & rules to tighten your macOS with your own firewall. The setup is very 
simple, just follow the instructions below. 

#### Setup
First install this repo following the instruction [here](https://github.com/aselvan/scripts?tab=readme-ov-file#scripts). Next, install the firewall using one of the following methods (install script or manual). It is higly recommended to use the install script method.

### Install script
Run the ```sudo -E firewall_install.sh``` script

### Manual
Copy ```pf_rules_simple.conf``` file to ```/etc/pf.anchors/``` and 
edit ```/etc/pf.conf``` file and append the following lines below.

```
# ------------------------ Custom firewall rules anchor ------------------------
# Disclaimer: This is a free utility from selvansoft.com provided "as is" without 
# warranty of any kind, expressed or implied. Use it at your own risk!
#
# Source: https://github.com/aselvan/scripts/tree/master/firewall
#
anchor "com.selvansoft"
load anchor "com.selvansoft" from "/etc/pf.anchors/pf_rules_simple.conf"
# ------------------------ Custom firewall rules anchor ------------------------
```
After the setup above, you now can run ```sudo firewall start``` for rules take effect immediately or 
optionally, you can reboot your mac to validate if the rules survive after boot (they should).

**Note:** Unfortunately, Apple wipes custom rules like these during every MacOS update 
so you have to reapply the above change to ```/etc/pf.conf``` everytime after MacOS update! 
To make it easy, there is a handy script ```firewall_install.sh``` available that can 
be used to make this change instead of manually editing ```/etc/pf.conf```. So everytime you have a
macOS update, run this install script ```sudo -E firewall_install.sh``` 

#### Customization (optional)
Though these firewall rules work just fine *'as is'*, you might want to consider 
customizing it a bit. For my needs, by default, I allow certain things like 
**ssh** within my local network i.e. *192.168.1.0/24*. You may or may not want to 
do the same so you can modify them to fit your needs. The entries you need 
to revise are in `pf_rules_simple.conf` as shown below.
```
allowed_tcp_ports = "{ 22, 554, 3689 }"
allowed_udp_ports = "{ 554, 5353 }"
allowed_ips = "{ 192.168.1.0/24 }"
```

#### Advanced Usage (optional)
The ```firewall``` shell script can be used to allow/block specific IPs on the fly. 
This is useful if you want to allow access to a remote IP inbound or outbound temporarily 
for whatever reason. This can be done as shown below.
```

arul@lion$ sudo firewall addip 8.8.8.8
Adding 8.8.8.8 to the dynamic_list table...

arul@lion$ sudo firewall showtable
Showing dynamic_list table...
--- Allowed table: dynamic_list ----
   8.8.8.8
--- Blocked table: blocked_list ----
   120.192.0.0/10
--- non-routable table: non_routable_list ----
   10.0.0.0/8
   172.16.0.0/12
   192.168.0.0/16

arul@lion$ sudo firewall deleteip 8.8.8.8
Deleting 8.8.8.8 from the dynamic_list table..

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
Listing firewall rules ...
--- Global rules ---
scrub-anchor "com.apple/*" all fragment reassemble
anchor "com.apple/*" all
anchor "com.selvansoft" all
--- Anchor: com.selvansoft rules ---
block return log all
block return out quick from any to <blocked_list>
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
pass in inet proto tcp from 192.168.1.0/24 to any port = 554 flags S/SA keep state
pass in inet proto tcp from 192.168.1.0/24 to any port = 3689 flags S/SA keep state
pass in inet proto udp from 192.168.1.0/24 to any port = 554 keep state
pass in inet proto udp from 192.168.1.0/24 to any port = 5353 keep state
pass in proto tcp from <dynamic_list> to any port = 22 flags S/SA keep state
pass in proto tcp from <dynamic_list> to any port = 554 flags S/SA keep state
pass in proto tcp from <dynamic_list> to any port = 3689 flags S/SA keep state
pass in proto udp from <dynamic_list> to any port = 554 keep state
pass in proto udp from <dynamic_list> to any port = 5353 keep state
block return in quick from <non_routable_list> to any
--- Dynamic table list (if any) ---
--- Blocked table list (if any) ---
   120.192.0.0/10
--- non-routable table list (if any) ---
   10.0.0.0/8
   172.16.0.0/12
   192.168.0.0/16

```
