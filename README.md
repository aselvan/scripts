# scripts
[![status-stable](https://img.shields.io/badge/status-stable-green.svg)](https://github.com/aselvan/scripts)
[![last commit](https://img.shields.io/github/last-commit/aselvan/scripts)](https://github.com/aselvan/scripts)

## Overview
This repo contains a large collection of random scripts that I have written over the years for automating repetitive things. I have the habit of scripting any tasks even if there is a slight chance that I may have to repeat the same task. While some are specific to my needs that can be customized for anyone, majority of them are parameterized so they work as is for anyone as a general handy tool. More than 90% of these are bash shell scripts but it also has some with perl, python and even PHP. While all of these run natively on Linux or MacOS, some require additional binaries installed on your OS with package managers like brew (on macOS) or apt/yum/other (on Linux). I usually mention at the top a script if it requires such binary packages that may or may not be part of the basic OS. I do use a lot of these on a day to day basis and some are old/obsolete etc. Follow the setup section below on how to set them up and use them.

## Setup
While many of these can run standalone, I started requiring common functions located in util/logger.sh & util/functions.sh as includes. So the best way to use them is to clone the entire repository instead of cherry picking one or more scripts. You can clone the repo exactly as shown (option#1) below or set environment variable SCRIPTS_GITHUB (option#2) to point to where you cloned. Enjoy!

- Clone to your HOME directory like so $HOME/src/scripts.github (or)
- Clone to any other directory as long as you set a bash env variable SCRIPTS_GITHUB to point to the toplevel directory


### Toplevel directories

- #### /android
  Andrioid adb scripts, busybox setup, cron, phone status/settings & misl scripts

- #### /car/tesla
  Wrapper script to call tesla API to do various things like lock/unlock door, honk, location, enable keyless drive, etc.

- #### /tools
  Lot of useful/generic wrapper scripts here for file/directory/media manipulation etc.

- #### /macos
  MacOS only scripts to manupilate things under MacOS like cache cleanup, free wifi, network, launchctl cleanup etc.

- #### /raspberrypi
  Various tools/scripts/howtos to build a image for RaspberryPI to be used as IoT device or pentest device

- #### /firewall
  PF (packet filter) based firewall script to tighten your macOS (works on Yosemite onwards) with your own firewall. Very simple to setup by editing the /etc/pf.conf file (read the pf_rules_simple.conf)

- #### /iot/kasa
  Simple script to call Kasa (TPlink) IoT bulb to turn on/off commandline. The kasa phone app is terrible and often looses connection to bulb and this script is very handy and reliable.
 
- #### /freestyle-libre 
  Script to import the blood glucose data exported from [freestyle-libre](https://www.freestylelibre.us/) reader, [libreview](https://libreview.com) export file as well as the [liapp](https://play.google.com/store/apps/details?id=de.cm.liapp&hl=en_US) (android application). The data is stored in local sqlite DB and allows you to calcuate daily, weekly and monthly A1C from historical data. 

- #### /googleapps_scripts
  Scripts for Google Apps Scripting platform

- #### /googlehome_scripts
  My google home automation scripts.

- #### /docker-jitsi
  Run your own Jitsi (opensource equivelent of google meet, zoom etc) audio/video conf with dockerized images.

- #### /docker-scripts
  Misl. shell scripts to manipulate (clean, prune, tune, list, docker containers).

- #### /linux
  Linux related scripts
  
- #### /misl
  Misl scripts 

- #### /router/asus-gt-ax11000
  Misl notes and worarounds scripts for ASUS GT-AX11000 router. 
  
- #### /security
  Security, password, encryption related random scripts

- #### /tools
  Random scripts for various things

- #### /wifi-sdcards
  Scripts for wifi enabled SD cards


