#!/bin/bash
#
# gpg_backup.sh --- Script to backup or referesh PGP keys.
#
# NOTE: this is for my personal use but feel free to copy/modify for your use.
#
# Description:
# exports ascii version of all 3 keys (home, work, yubikey,yubikey2, usbc) to 
# local disk as well as update key servers. 
#
# Additional info:
# Both yubi and yubi2 (for both old and new keys) are just a pointer in 
# the ~/.gnupg files since the original is imported to yubikeys. We got the 
# original keys saved with *_master.asc, however for key1(yubi) we may have 
# lost it since we did not backup but the yubi2 is backed up which can be written 
# back to yubi (key1) so we have both in sync. When listing keys in gpg you 
# will see '>' sign in front of keys that are really pointers.
#
# Author:  Arul Selvan
# Version: Feb 17, 2012

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
key_home="${HOME}/data/personal/keys"
keyservers="keys.gnupg.net keyserver.ubuntu.com keys.openpgp.org"
keys="0x451A1B6C 0xF81609CB 0x6675D56A 0x0E2A2DE0 0x72A50CEF"
public_template="${key_home}/Arul_Selvan_GPG_public_"
private_template="${key_home}/Arul_Selvan_GPG_private_"

referesh() {
  echo "[INFO] Refreshing key servers..." | tee -a $log_file
  for ksrv in $keyservers; do
    gpg --keyserver $ksrv --send-keys $keys 2>&1 | tee -a $log_file
  done
}

backup() {
  echo "[INFO] Backing up ascii version of private and public keys..." | tee -a $log_file
  if [ ! -d $key_home ]; then
    echo "[ERROR] key home directory '$key_home' is an invalid/non-existent path... exiting" | tee -a $log_file
    exit
  fi

  #all
  #gpg -a --export > ${public_template}all.asc
  #gpg -a --export-secret-keys > ${private_template}all.asc

  for key in $keys; do
    echo "[INFO] exporting $key to file ${public_template}${key}.asc and ${private_template}${key}.asc" | tee -a $log_file
    gpg -a --export $key > ${public_template}${key}.asc
    gpg -a --export-secret-keys $key > ${private_template}${key}.asc
  done
}

usage() {
  echo "Usage: $my_name <backup|referesh>"
  exit 0
}

# ------------------ main ----------------------
if [ $# -eq 0 ]; then
  usage
fi

echo "[INFO] `date`: $my_name starting ..." > $log_file
case $1 in 
  backup)
    backup
  ;;
  referesh)
    referesh
  ;;
  *)
    usage
  ;;
esac

