#!/bin/bash
#
# symantec_vipaccess_key.sh --- extract the secret key from Symantec VIPAccess app
#
# Description:
# -----------
# This script extracts the secret keys (and ID) from Symantec VIPAccess application 
# on MacOS so it can be used in Google Authenticator, or oathtool or any 2F TOTP 
# generators. No need for yet another app (i.e. VIPaccess app) for 2F needs on your 
# phone or desktop.
#
# PreReq: qrencode [ install w/ 'brew install qrencode']
#
# How to use:
# ----------
# Run this script on a mac (where you instsalled the VIPaccess app) on a terminal 
# and follow the prompt. At the end of the run, the script will print the VIPAccess ID 
# and secret which you can add to your Google Authenticator either manually or create 
# a QRcode image (shown at end).
# 
# Your run output should look like this below...
#
# $ ./symantec_vipaccess_key.sh 
# [INFO] You will be asked 4 times for keychain password ...
# [INFO] Just copy and paste the password below each time when asked.
# [INFO] Password:  xxxxxxxxxxxxxxxxxxxxxxxx
# [INFO] --- Press enter to continue ---
#
# [INFO] Symantec VIPAccess ID     : xxxxxxxxxxxxxxxxxxxxx
# [INFO] Symantec VIPAccess serect : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#
# Grab the secret from about to create a QR code image as shown below to scan 
# it in Google Authenticator.
#
# qrencode -o key.png "otpauth://totp/fidelity:loginusername?secret=xxxxxxxxxxxxxxxxxxxx&issuer=SymentacVIP"
#
# Also, you can use this extracted secret with oathtool.sh script found in this directory 
# to generate your TOTP on MacOS, or Linux on commandline i.e. no app/tool is needed.
#
# Ref: https://github.com/ykhemani/vipaccess
# Ref: https://github.com/p120ph37
#
# Author:  Arul Selvan
# Version: Mar 21, 2021 
#

os_name=`uname -s`
my_name=`basename $0`
options="s:vlh"
do_log=0
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
openssl_opt="enc -d -aes-256-cbc -a -in"

# Aaron (https://github.com/p120ph37) identified the AES_KEY by tracing the crypto 
# library calls that the Symantec VIP Access app makes.
AES_KEY=D0D0D0E0D0D0DFDFDF2C34323937D7AE

# VIPAccess keychain file
keychain_old="/Users/${USER}/Library/Keychains/VIPAccess.keychain"
keychain_new="/Users/${USER}/Library/Keychains/VIPAccess.keychain-db"
keychain=""

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -l          ==> log [default: no logging].
  -h          ==> usage

  example: $my_name -l

EOF
  exit
}

log() {
  local msg=$1

  if [ $do_log -eq 0 ] ; then
    return
  fi
  echo $msg |tee -a $log_file
}

check_keychain() {
  if [ -f $keychain_old ] ; then
    keychain="$keychain_old"
  elif [ -f $keychain_new ] ; then
    keychain="$keychain_new"
  else
    echo "[ERROR] keychain file missing!"
    exit 2
  fi
}

# extract ID and secret
do_extract() {
  # extract the MacOS serial number
  serial_number=$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')
  if [ -z $serial_number ]; then
    echo "[ERROR] error reading serial number!"
    exit 1
  fi
  log "[INFO] MacOS serial number: $serial_number"
  
  # construct keychain password
  keychain_password="${serial_number}SymantecVIPAccess${USER}"

  echo "[INFO] You will be asked 4 times for keychain password ..."
  echo "[INFO] Just copy and paste the password below each time when asked."
  echo "[INFO] Password:  $keychain_password"
  echo "[INFO] --- Press enter to continue ---"
  read

  # unlock keychain (may prompt multiple times so print the password so user can enter
  security unlock-keychain -p ${keychain_password} ${keychain}
  
  # get the encrypted ID and secret key.
  id_crypt=$(security find-generic-password -gl CredentialStore ${keychain} 2>&1 | egrep 'acct"<blob>' | awk -F\<blob\>= '{print $2}' | awk -F\" '{print $2}')
  if [ -z $id_crypt ]; then
    echo "[ERROR] error reading ID!"
    exit 2
  fi
  log "[INFO] Encrypted ID: $id_crypt"
  
  key_crypt=$(security find-generic-password -gl CredentialStore ${keychain} 2>&1 | grep password: | awk '{print $2}' | awk -F\" '{print $2}')
  if [ -z $key_crypt ]; then
    echo "[ERROR] error reading secret key!"
    exit 3
  fi
  log "[INFO] Encrypted secret key: $key_crypt"
  

  # decrypt the encrypted ID and secret key and print to console
  id_txt=$(openssl enc -aes-128-cbc -d -K ${AES_KEY} -iv 0 -a <<< ${id_crypt} | sed -e 's#Symantec$##')
  if [ -z $id_txt ]; then
    echo "[ERROR] error decrypting ID!"
    exit 4
  fi
  key_txt=$(openssl enc -aes-128-cbc -d -K ${AES_KEY} -iv 0 -a <<< ${key_crypt} | base32)
  if [ -z $id_txt ]; then
    echo "[ERROR] error decrypting secret key!"
    exit 5
  fi

  # print key and secret
  echo "[INFO] Symantec VIPAccess ID     : $id_txt"
  echo "[INFO] Symantec VIPAccess serect : $key_txt"
}


# ---------------- main entry --------------------

# commandline parse
while getopts $options opt; do
  case $opt in
    l)
      do_log=1
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

echo "" > $log_file
log "[INFO] `date`: $my_name starting ..."

# check for keychain file
check_keychain

do_extract

