#!/bin/sh
#
# asus_usbmount.sh -- mounts the usb drive in ASUS GT-AX1100 as /opt
#
#   This is needed since stock firmawre has /opt as readonly with links
#   pointing to a /tmp/opt. The problem is while there are read-only
#   links created by firmware for most /opt/ directories, the /var is
#   missed which is essential for Enware install. So this script mounts
#   the entier /opt on top the external usb where we have write access
#
####### DISCLAIMER: ######## 
# If you do choose to use this script, you are using it at your own risk 
# and I am not liable for any loss or damage you have caused by using 
# this script.
############################
#
# Note: 
#  This eclips the /opt from firmware where there is one scripts/
#  directory and I am sure if firmware needs it but its hidden with this
#  mount below.
#
# Install instruction:
# -------------------
#  copy this file to /jffs/asus_usbmount.sh and make it persist on nvram & reboot
#   nvram set script_usbmount="/jffs/asus_usbmount.sh"
#   nvram commit
#   reboot
#
# Author:  Arul Selvan
# Version: Apr 21, 2020
# Version: Oct 3 , 2022

# In my ASUS-GT AX11000, the top usb slot mapps to be sda1 
# TODO: change this to your device name
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

#
# TODO: change this to your ssh-key(s)
#
# TODO: once ASUS fixed the bug, add keys via admin UI and remove everything below.
# ASUS GT-AX11000 firmware Version:3.0.0.4.384_8011 has a bug which 
# looses all ssh pub keys other than the first one. I need more keys
# so the following is a work around until ASUS fixes that problem.
#
# update: even as of version "3.0.0.4.386_49599-g8352df7" problem still persists!!! (Oct 3, 2022)
my_ssh_key1="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAvGze5SVRGLbAk2ZPIBgBnMZXx+y/e3mni07wa9iZvAlCUwSelg+GfLqrlQqNvymLYhmFDJ9Jou3oVjOQCT36AaaNiD5GiRRQW6XZvsVjvRxQ9ASPsBZihEAQMFdy8iq7XUsaKzpu7wnlMkwb4RjOYC6mkHPKuvpbtPoRn0fd7ZgdmG2xHchsgp6TwLg7EHSUR6jmrfwXm/fc8NGpyxa3VHSfPzk6XSk7/D3iiWMWUlP0dvdyJXn6Yy06ItgbOtIBtqQPG7aGREu/LCT249mRAXJ9WRG6oljxPK2z4sCmkMqUFuZjC0BoDM458ueeZW1eWVMYHuiNxxdycOhNPxSQyQ== aselvan@panther"
my_ssh_key2="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIUWiLXe4oIQ5MFqHAanzoxGg1MewV4ro9CsbruT4LoU4u3E1Ocdul+rWeGJuYaPcA0Qg7BjPwlSgi22GxqljoQKA0uw2CizB24up2M51Wb4mqZNG2WwRpwfCsRju6p2ymRhziBe052zRgH9yEwBMcAgqHwL7MDRniqVz0IzOLmK4a19I7S+4L2eSCZDjzGv5S0ytW8pTrzt4aCqLG7SGFWHl9P1g5cpY9kz0fqLhATEU/dNgBjffetb0x+esjI9L3x9GWYzzBlqr0hEv3lzDoNUrwCAMI+4eCNpGkTcliIelMsXhDdBFAB1uTrllffOVYK4s3vkfvLLgbl8otUkCR root@gorilla"
my_ssh_key3="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD6EigjJFrLo+SiCkSQH2g4N3S566zZocYK0e5d0uCKVgLB5sUzEtpA9J4VTIGq1QtaQAsuOYqhEsAb6NJTQi+Ny+dX/Z99tQ1SSiCtKNe51aufDrGKeNLK/fAxYmtdG+8rcIFkzzhUw82HEYmJExS6c2dbhh3z+SytqNAQPysDekpyWXV5usPHMku3CtL3D+Pl3kPRY/RMIJXIeEnmFQ9Q5/vBbnnTFCfP3zLX4z6AyFSFifCKUzDPsOhY3hYkumxgaCZKeMJgkIEIrfsTEwpbtfFqamyy6s7NSFieuGHSIXMmGGkMtVDtZklOSLFp6KF1ceZNzancNO4gDll7pR/B cub900@cub900mac"
my_ssh_key4="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCZ6btZe5G0Asw1HwqbThRxrk41r4zRpEI7Zl3t4IflW+i+UoZHBWO98FHDf6Uap2s3MSOeXd+EDceIWMpYqnWWiSPBL0JgfKrx4Z2Oyj/0hmCBSL7kMqr/OP3BVi6nRKsDqNO6wHYx1RvPgP7Xbyj9haSF2APacT254d3u3EWhAU52tsR1jPfCFVafkNxLKP6bfxNilWQhvxYL9yezPmHMfpi+4ADt8HQA6xJN66Q0TsaKxQHC5qOGpuzQ1RfQRWS8oHjJD1VG6rZznkCuDnsPVxMELMs0ciZB4cxpSPfL2e/A+/NTYGTQrgOhWQx33a3Hg/iIWgHTc3PrsJUa/JnM5BHmeLB8MlDqT8VZe2LEbyIV4qcdDj1FGLBil4Ji+9YFvazdcvJoSVktBcqrUUWbdXRwcZz3ndVV5LBpCRQzRZgBZ/BVw5w9FmnC1VQLsnGBXlwDo1kmXv5ab13x1b0lPBnwbONJ8iUv3m6jEgVU+Vorzf6Zdar65YECfj0xLM= arul@eagle"


# append more keys since firmware loses everything but first one.
echo "" >> /tmp/home/root/.ssh/authorized_keys
echo $my_ssh_key1 >> /tmp/home/root/.ssh/authorized_keys
echo "" >> /tmp/home/root/.ssh/authorized_keys
echo $my_ssh_key2 >> /tmp/home/root/.ssh/authorized_keys
echo "" >> /tmp/home/root/.ssh/authorized_keys
echo $my_ssh_key3 >> /tmp/home/root/.ssh/authorized_keys
echo "" >> /tmp/home/root/.ssh/authorized_keys
echo $my_ssh_key4 >> /tmp/home/root/.ssh/authorized_keys
