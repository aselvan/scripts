#!/bin/bash
#
# symantec_vipaccess_key.sh --- extract the secret key from Symantec VIPAccess app
#
# Description:
# -----------
# This script extracts the secret keys (and ID) from Symantec VIPAccess application 
# on MacOS so it can be used in Google Authenticator, or oathtool or any 2F TOTP 
# generators, no need for multiple apps for 2F needs on your phone or desktop.
#
# How to use:
# ----------
# The extracted secret key can be added to Google Authenticator app by typeing in 
# the key or create a QR code as shown below to scan it in Google Authenticator
#
# qrencode -o key.png "otpauth://totp/fidelity:loginusername?secret=<outputofthisscript>&issuer=SymentacVIP"
#
# Also, you can use this extracted key with oathtool.sh found in this directory
# to generate your TOTP on MacOS, or Linux (see oathtool.sh)
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

# VIPAccess keychain location
keychain="/Users/${USER}/Library/Keychains/VIPAccess.keychain"

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

  echo "[INFO] You may get multiple prompts for keychain password ..."
  echo "[INFO] if so, copy and paste below password each time when asked."
  echo "[INFO] Password:  $keychain_password"
  echo "[INFO] --- Press any key to continue ---"
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
do_extract

