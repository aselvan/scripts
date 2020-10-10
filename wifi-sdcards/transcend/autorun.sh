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
jffs2_fs="/mnt/mtd"
log_file="$jffs2_fs/autorun.sh.log"
access_log="$jffs2_fs/access.sh.log"
# set debug=1 to start telnetd
debug=0

# First, grab the previous logs from jffs2 writable mount to SD card. This allows us to 
# access/view the log files by booting card twice 
if [ -f $access_log ]; then
   cp $access_log $sd_path/.
fi
if [ -f $log_file ]; then
   cp $log_file $sd_path/.
fi

# --- make SD readonly ASAP! (fat32 can not handle multiple mounts) ---
# we need our busybox to make SR readonly i.e. 'sed' is not availabe in stock firmware
cp $sd_path/busybox-armv5l $sd_path/dropbearmulti-armv5l  /sbin/.
chmod a+x /sbin/busybox-armv5l /sbin/dropbearmulti-armv5l

# Now, make SD read-only
/sbin/busybox-armv5l sed -i.orig -e 's/ -w / /' -e 's/-o iocharset/-o ro,iocharset/' /usr/bin/refresh_sd
/usr/bin/refresh_sd

# Rest of the work of autorun.sh starts here ....
echo "[INFO] `date`: $0 starting ..." > $log_file

# telnet access to initially debug and setup everything.
# CAUTION: You must comment/remove the line below once dropbear is working as expected.
if [ $debug -ne 0 ] ; then
  echo "[WARN] debug mode, enabling telnet ... " >> $log_file
  telnetd -l /bin/bash &
fi

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

echo "[INFO] `date`: $0 completed." >> $log_file
/sbin/busybox-armv5l sync
