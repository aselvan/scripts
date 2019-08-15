#!/bin/bash

#
# Description:
# Shell script to force reboot obihai daily 
#
# Author:  Arul Selvan
# Version: Dec 6, 2014

obihai="192.168.1.128"
admin_passwd="<obihai_password_here>"
reboot_url="http://admin:$admin_passwd@$obihai/rebootgetconfig.htm"
output_html="/var/www/obihaiReboot.html"

/usr/bin/wget -q -O $output_html $reboot_url >/tmp/obihaiReboot.log 2>&1
