# macOS

### A collection of totally random scripts for macOS

- #### /macos.sh
  Wrapper for all macOS utilities in one single place, lot of useful tools and utilities.

- #### /diskutil.sh
  wrapper script over diskutils to format disk on MacOS

- #### /LaunchDaemons
  This directory contains my crontab entries converted to LaunchDaemon plist. Since Tahoe 26.2, Apple 
  decided to do the dumbest thing by killing cron i.e. not allowing cron "full disk access". Not sure
  what prompted them to kill this *nix gem that has been around almost 50 years!. Feel free to take
  these scripts and change it to fit your needs.

- #### /cleanup_cash.sh
  Script to cleanup cache/log to reclaim space [DEPRICATED: use macos.sh -c cleanup]

- #### /keychain.sh
  Handy script to store/retrive passwords in native MacOS keychain

- #### /locate_updatedb.sh
  Builds locate db for locate command

- #### /logtune.sh
  supress chatty logs on MacOS to help reduce wasted CPU & IO

- #### /iso2bootable.sh
  makes a bootable USB disk from ISO file on macOS

- #### /wifi_password.sh
  Read the wifi password from MacOS keychain

- #### /txt2mp3.sh
  convert text to mp3 using macOS tools

- #### /user.sh
  create/delete macOS users from commandline


- #### /spoof_mac.sh
  Spoof mac address, save current or restore or list

- #### /free_wifi.sh
  Shell script to get free wifi by spoofing an authenticated mac address on a paid wifi service like inflight wifi.

- #### /crashplan.sh
  Enable and disable crashplan service/agents.
