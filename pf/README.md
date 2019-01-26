# Install Guide

#### Overview

This is a Firewall script to tighten your macOS with your own firewall. The setup is very 
simple, just follow the instructions below.

#### Setup
- Copy the firewall script to a directory which is in your $PATH
- Copy rules file (pf_rules_simple.conf) to /etc/pf.anchors
- edit the /etc/pf.conf file and add an entry at the end as shown below (note: the anchor name can be anything)
```
# custom firewall anchor
anchor "yourdomain.com"
load anchor "yourdomain.com" from "/etc/pf.anchors/pf_rules_simple.conf"
```
- reboot your mac so firewall script will be in effect

#### Check status
```
firewall status
Listing firewall rules ...
--- Global rules ---
No ALTQ support in kernel
ALTQ related functions disabled
scrub-anchor "com.apple/*" all fragment reassemble
anchor "com.apple/*" all
anchor "yourdomain.com" all
--- Anchor yourdomain.com rules ---
No ALTQ support in kernel
ALTQ related functions disabled
block return log all
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
anchor "yourdomain.com/white_list" all
--- Whitelist rules ---
No ALTQ support in kernel
ALTQ related functions disabled
pass in proto tcp from <dynamic_ips> to any port = 22 flags S/SA keep state
pass in proto tcp from <dynamic_ips> to any port = 8080 flags S/SA keep state
--- Dynamic table list (if any) ---
No ALTQ support in kernel
ALTQ related functions disabled
```

