# README

## LaunchDaemons

#### Introduction
This directory contains most of my crontab entries converted into LaunchDaemon plist files. Starting with Tahoe 26.2, Apple made the dumbest decision by effectively killing cron by disabling Full Disk Access to cron. I have no idea what motivated them to retire a Unix tool that has been around for nearly fifty years. Feel free to use these scripts and modify them to suit your needs.

#### How to setup a launchctl entry

While LaunchAgent items run at user level, LaunchDaemons items run as privileged (sudo). Many of 
my crontab entries are from root crontab so the setup below is for system level launch entry. Follow
the steps below to validate, install, test and/or remove each item as needed.

##### The plist file requirment
Copy the plist file to /Library/LaunchDaemons/. The file needs to be owend by root:wheel 
with of 644 (owner rw other r).

- cp com.selvansoft.test.plist /Library/LaunchDaemons/.
- sudo chown root:wheel /Library/LaunchDaemons/com.selvansoft.test.plist
- sudo chmod 644 /Library/LaunchDaemons/com.selvansoft.test.plist

##### Check and validate plist
- plutil -lint /Library/LaunchDaemons/com.selvansoft.test.plist

##### Register/add
- sudo launchctl bootstrap system /Library/LaunchDaemons/com.selvansoft.test.plist

##### Validate launch item is shown by launchctl
- sudo launchctl print system/com.selvansoft.test

##### Manualy trigger to test
- sudo launchctl kickstart -p system/com.selvansoft.test

##### How to remove
- sudo launchctl bootout system /Library/LaunchDaemons/com.selvansoft.taskname.plist
