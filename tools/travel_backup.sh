#!/usr/bin/env bash
################################################################################
# travel_backup.sh --- simple backup script wrapper to use during travel to 
#                      safekeep daily pictures on cloud (both onedrive & gdrive)
#
# Note: this is hard coded to run from the laptop called eagle (Macbook air) 
#
# Author:  Arul Selvan
# Created: Apr 29, 2025
################################################################################
# Version History:
#   Jul 19, 2022pr 29, 2025 --- Original version
################################################################################

# version format YY.MM.DD
version=25.04.29
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Backup travel photos to onedrive & google drive"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="uc"
source_path="/Users/arul/Desktop/sa-photos"
usb1_backup="/Volumes/exfat128g/"
usb2_backup="/Volumes/travel/"
onedrive_backup="/Users/arul/mnt/onedrive"
gdrive_backup="/Users/arul/data/home/gdrive"


usage() {
  cat << EOF
$my_name --- $my_title
Usage: $my_name [options]
  -u ---> Only backup USB destinations 
          Destinations: $usb1_backup , $usb2_backup)
  -c ---> Only backup Cloud destinations
          Destinations: $onedrive_backup , $gdrive_backup)
example(s): 
  $my_name -u
  
EOF
  exit 0
}


usb_backup() {
  log.stat "Backup Type: USB drive"
  log.stat "Backup Source: $source_path" $green
  log.stat "Backup Start:  `date +'%D %H:%M:%S %p'`"

  log.stat "  - USB Backup"
  if [ -d $usb1_backup ] ; then
    log.stat "    USB location: $usb1_backup "
    simple_rsync.sh -s $source_path -d $usb1_backup
  else
    log.warn "    USB location: $usb1_backup not present, skipping"
  fi
  if [ -d $usb2_backup ] ; then
    log.stat "    USB location: $usb2_backup"
    simple_rsync.sh -s $source_path -d $usb2_backup
  else
    log.warn "    USB location: $usb2_backup not present, skipping"
  fi
  log.stat "Bakup End:  `date +'%D %H:%M:%S %p'`"
}

cloud_backup() {
  log.stat "Backup Type: Cloud (Onedrive & Google Drive)"
  log.stat "Backup Source: $source_path" $green
  log.stat "Backup Start:  `date +'%D %H:%M:%S %p'`"

  log.stat "  - Cloud Backup"
  if [ -d $onedrive_backup ] ; then
    log.stat "    OneDrive: $onedrive_backup"
    simple_rsync.sh -s $source_path -d $onedrive_backup
  else
    log.warn "    OneDrive path: $onedrive_backup not present, skipping"
  fi

  if [ -d $gdrive_backup ] ; then
    log.stat  "    GDrive: $gdrive_backup"
    simple_rsync.sh -s $source_path -d $gdrive_backup
  else
    log.warn "    GDrive path: $gdrive_backup not present, skipping"
  fi

  log.stat "Bakup End:  `date +'%D %H:%M:%S %p'`"
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile
check_root

# parse commandline options
while getopts $options opt ; do
  case $opt in
    u)
      usb_backup
      ;;
    c)
      cloud_backup
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ $# -eq 0 ]; then
  usage
fi
