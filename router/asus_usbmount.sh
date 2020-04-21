#!/bin/sh
#
# asus_usbmount.sh -- mounts the usb drive in ASUS GT-AX1100 as /opt
#
#   This needed since stock firmawre has /opt as readonly with links
#   pointing to a /tmp/opt. The problem is while there are read-only
#   links created by firmware for most /opt/ directories, the /var is
#   missed which is essential for Enware install. So this script mounts
#   the entier /opt on top the external usb where we have write access
#
# Note: This eclips the /opt from firmware where there is one scripts/
# directory and I am sure if firmware needs it but its hidden with this
# mount below.
#
# Install instruction:
# -------------------
#  copy this file to /jffs/asus_usbmount.sh
#  nvram set script_usbmount="/jffs/asus_usbmount.sh"
#  nvram commit
#
# Author:  Arul Selvan
# Version: Apr 21, 2020
#
# In my ASUS-GT AX11000, the top usb slot mapps to be sda1 
my_usb=/dev/sda1

# check and make sure it is good before attempting to mount
/bin/df $my_usb >/dev/null 2>&1
if [ $? -eq 0 ] ; then
  /bin/mount $my_usb /opt
  sleep 2
  ls -l /opt/ >/tmp/asus_usbmount.dirlist
else
  echo "$my_usb is not present, skiping mount" >/tmp/asus_usbmount.log
fi
