#!/bin/sh
#
# autorun.sh - setup services to run on Transcend SDWifi card 
# 
# This script needs to be in the root directory of the SD card and is automatically 
# executed by the Transcend boot process. This script copies necessary binaries to 
# run a sshd (dropbear) only when the card is connected to a trusted network. The 
# users need to edit the access.sh file to enter the necessary info (see access.sh)
#
# Author:  Arul Selvan
# Version: May 2, 2014
# 
# CREDIT: this script is based on information and code shared from original authors below.
# https://www.pitt-pladdy.com/blog/_20140202-083815_0000_Transcend_Wi-Fi_SD_Hacks_CF_adaptor_telnet_custom_upload_/
# http://haxit.blogspot.ch/2013/08/hacking-transcend-wifi-sd-cards.html
# 
# DISCLAIMER: Use it at your own risk. I am not responsible for any loss or damage to your property.

sd_path="/mnt/sd/custom"
log_file="$sd_path/autorun.log"
pre_access_log="/mnt/mtd/access.sh.log"
# set debug=1 to start telnetd
debug=0

echo "[INFO] `date`: $0 starting ..." > $log_file
sync

# make sure we are running on the wifiSD (just check for presence of mount point and this file)
# ubuntu trys to run this file so we need to make sure it doesn't crap out if someone runs it
if [ ! -f $sd_path/autorun.sh ] ; then
   echo "[ERROR] autorun.sh missing, this may not be a Transcend wifiSD card... exiting" >> $log_file
   exit
fi

# telnet access to initially debug and setup everything.
# CAUTION: You must comment/remove the line below once dropbear is working as expected.
if [ $debug -ne 0 ] ; then
  echo "[WARN] debug mode, enabling telnet ... " >> $log_file
  telnetd -l /bin/bash &
fi

echo "[INFO] copy our busybox ..." >> $log_file
# setup a busybox with more applets than the one comes with Transcend firmware
cp $sd_path/busybox-armv5l $sd_path/dropbearmulti-armv5l  /sbin/.
chmod a+x $sd_path/busybox-armv5l  $sd_path/dropbearmulti-armv5l

# setup a simple wrapper script to run anything using our busybox instead of
# transcend's stock firmware w/ out messing up anything. This allows running
# anything using our busybox. ex: run ifconfig
echo "[INFO] setup run script for using our busybox ..." >> $log_file
echo "#!/bin/sh" >/bin/run
echo "exec /sbin/busybox-armv5l \$*" >> /bin/run
chmod a+x /bin/run

# setup dropbear
echo "[INFO] setting up dropbear ..." >> $log_file
ln -s /sbin/dropbearmulti-armv5l /sbin/dropbear
ln -s /sbin/dropbearmulti-armv5l /sbin/dropbearkey
ln -s /sbin/dropbearmulti-armv5l /usr/bin/scp
ln -s /sbin/dropbearmulti-armv5l /usr/bin/ssh
mkdir /etc/dropbear
chmod 0700 /etc/dropbear
cp $sd_path/dropbear_rsa_host_key $sd_path/dropbear_dss_host_key $sd_path/authorized_keys /etc/dropbear/.
chmod 0600 /etc/dropbear/authorized_keys
chmod a+r /etc/dropbear/dropbear_*
ln -s /etc/dropbear ~/.ssh
# dropbear needs /etc/passwd file at the minimum
echo "root:x:0:0:root:/:/bin/sh" >/etc/passwd
touch /var/log/lastlog
touch /var/log/wtmp

# add custom dhcp code (ntpd & local access)
echo "[INFO] setup ntp, and hookup script to run after DHCP offer/bind ..." >> $log_file
cat $sd_path/ntpd.sh >>/etc/dhcp.script
cat $sd_path/access.sh >>/etc/dhcp.script

# finally, check and see if there is previous log file from before and copy if
# we find it to SD path. This is done so we can boot twice to learn 
# the IP address that is assigned (previous log contains IP). This file can't be 
# copied to SD path the first time as when access.sh runs it is too late to 
# copy anything to SD.
if [ -f $pre_access_log ]; then
   echo "[INFO] $pre_access_log found, copying to $sd_path" >> $log_file
   cp $pre_access_log $sd_path/.
else
   echo "[INFO] $pre_access_log file is not found!" >> $log_file
fi
# just before turning sd to readonly for this host, sync the log file
echo "[INFO] `date`: $0 completed." >> $log_file
/sbin/busybox-armv5l sync

# safety - change mount to ro (since fat32 can not handle multiple mounts)
# Update: for now leave it writable since we need to get the IP assigned
# to this computer which access.sh (as part of dhcp.script we added above)
busybox-armv5l sed -i.orig -e 's/ -w / /' -e 's/-o iocharset/-o ro,iocharset/' /usr/bin/refresh_sd
refresh_sd
