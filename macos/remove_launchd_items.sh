#!/bin/sh
#
# remove_launchd_items.sh - removes unwanted autolaunch entries from MacOS 
# stock image. Must run with sudo
#
# Author:  Arul Selvan
# Version: Sep 1, 2014
#
extended="$1"

uid=`id -u`
if [ $uid -ne 0 ]; then
  echo "You need to run this script as sudo" 
  exit
fi

# items to remove safely
items_to_remove="\
  /System/Library/LaunchDaemons/org.apache.httpd.plist \
  /System/Library/LaunchDaemons/org.ntp.ntpd.plist \
  /Library/LaunchDaemons/com.adobe.fpsaud.plist \
  /Library/LaunchDaemons/com.google.keystone.daemon.plist \
  /Library/LaunchDaemons/com.omnigroup.OmniSoftwareUpdate.OSUInstallerPrivilegedHelper.plist \
  /Library/LaunchDaemons/com.oracle.java.Helper-Tool.plist \
  /Library/LaunchAgents/com.adobe.AAM.Updater-1.0.plist \
  /Library/LaunchAgents/com.google.keystone.agent.plist \
  /Library/LaunchAgents/com.oracle.java.Java-Updater.plist \
  /Library/LaunchDaemons/com.puppetlabs.pxp-agent.plist" 

# this list may be unsafe, so if there are issues you can always
# reload them back w/ launchctl load -F $name
additional_items_to_remove="\
  /System/Library/LaunchDaemons/com.apple.systemstats.daily.plist \
  /System/Library/LaunchDaemons/com.apple.systemstatsd.plist \
  /System/Library/LaunchDaemons/com.apple.systemstats.analysis.plist \
  /System/Library/LaunchAgents/com.apple.NowPlayingTouchUI.plist \
  /System/Library/LaunchAgents/com.apple.touchbar.agent.plist \
  /Library/LaunchDaemons/com.crashplan.engine.plist"

others="\
  /Library/LaunchDaemons/com.fitbit.galileod.plist \
  /Library/LaunchDaemons/net.tunnelblick.tunnelblick.tunnelblickd.plist \
  "
# note: crash plan is the stupid app RP installs which constantly 
# consumes cpu (even when set to do backup in a schedule) and wastes
# lot of resources!

# normal items
echo "Removing totally unneeded items..."
for name in $items_to_remove; do 
  if [ -e $name ]; then
    echo "Removing $name"
    launchctl unload -w $name
  fi
done

# additional items (if needed)
if [[ ! -z $1  && $1 = "--extended" ]]; then
  echo "Removing additional items ..."
  for name in $additional_items_to_remove; do
    if [ -e $name ]; then
      echo "Removing $name"
      launchctl unload -w $name
    fi
  done
fi
