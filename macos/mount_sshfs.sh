#!/bin/sh

#
# mount_sshfs.sh --- wrapper script for automountd to invoke
#
# This should be soft linked (or copied) to /sbin for automountd. Apple makes 
# it harder now (i.e. since Catalina update) by making /sbin readonly so you 
# have to turn off SIP in order to place this as a soft link under /sbin for 
# ssh automount path defined in /etc/auto_sshfs to work.
#
# ln -s mount_sshfs.sh /sbin/mount_sshfs 
#
# Author:  Arul Selvan
# Version: Apr 12, 2020
#
log_file=/tmp/mount_ssh.log

echo "[INFO] `date`: mount_sshfs.sh starting " > $log_file
echo "[INFO] Mount command:  $@ ..." >> $log_file
sudo  /usr/local/bin/sshfs $@
