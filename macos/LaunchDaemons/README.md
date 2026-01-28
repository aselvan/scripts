# README

## LaunchDaemons

#### Introduction
This directory contains most of my crontab entries converted into LaunchDaemon plist files. Starting with Tahoe 26.2, Apple made the dumbest decision by effectively killing cron by disabling Full Disk Access to cron. I have no idea what motivated them to retire a Unix tool that has been around for nearly fifty years. Feel free to use these scripts and modify them to suit your needs.

#### How to setup a launchctl entry
While LaunchAgent items run at user level, LaunchDaemons items run as privileged (sudo). Many of 
my crontab entries are from root crontab so the setup below is for system level launch entry. Follow
the steps below to validate, install, test and/or remove each item as needed.

##### Requirements for LaunchDaemon tasks
- All the plist file should reside in /Library/LaunchDaemons/ directory.
- The plist files needs to be owend by ```root:wheel```
- The permission should be 644 (i.e. owner/rw other/r). 
- The ProgramArguments should not point to path inside TCC (Transparency, Consent, and Control) protected area. Typically $HOME and everything under that are TCC protected. 
- The ProgramArguments script/app should not access anything inside TCC protected area.

The following is an example of setting up a test task which doesn't do much other than echo 
runtime to a stdout.

##### Copy plist
```bash
cp com.selvansoft.test.plist /Library/LaunchDaemons/.
sudo chown root:wheel /Library/LaunchDaemons/com.selvansoft.test.plist
sudo chmod 644 /Library/LaunchDaemons/com.selvansoft.test.plist
```

##### Check and validate plist
```bash 
plutil -lint /Library/LaunchDaemons/com.selvansoft.test.plist
```

##### Register/add task
```bash 
sudo launchctl bootstrap system /Library/LaunchDaemons/com.selvansoft.test.plist
```

##### Validate task as shown by launchctl
```bash 
sudo launchctl print system/com.selvansoft.test
```

##### Manualy trigger task
```bash
sudo launchctl kickstart -p system/com.selvansoft.test
```

##### Test/Debug: check last run exit code of task
```bash
sudo launchctl print system/com.selvansoft.test | grep "last exit code"
````

##### Remove the task
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.selvansoft.taskname.plist
```
