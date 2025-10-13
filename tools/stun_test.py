#!/usr/bin/python3
#
# stun_test.py --- simple script to discover ip/port via stun server
#
#
# Author:  Arul Selvan
# Version: Oct 13, 2025
#
# Prereq:  
#   pip3 install pystun3
#

import stun

# You can specify a known STUN server
stun_host = "stun.l.google.com"
stun_port = 19302

nat_type, external_ip, external_port = stun.get_ip_info(
    source_ip="0.0.0.0",
    stun_host=stun_host,
    stun_port=stun_port
)

print("=== STUN Diagnostic ===")
print(f"STUN Server     : {stun_host}:{stun_port}")
print(f"NAT Type        : {nat_type}")
print(f"Public IP       : {external_ip}")
print(f"Public Port     : {external_port}")

