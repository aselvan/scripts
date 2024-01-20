#!/usr/bin/env bash
#
# enc_account.sh --- encrypts the account password plain file and makes a backup 
# to remote ssh path.
#
# Note: this encypts the plain file w/ openssl (symetric), gpg (PKI) and Yubi 
# hardware key creating 3 files. This is a highly personalized script for my needs
# but if 
# you find it useful feel free to use it but you have to make lot of changes
# to fit our needs.
#
# Author:  Arul Selvan
# Version: Dec 26, 2018
#
# Version History
#   Dec 26, 2018  --- original version
#   Jan 20, 2024  --- added veracrypt, phone additional storage, use logger/function 
#                     includes, openssl options etc
#

# version format YY.MM.DD
version=24.01.20
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Encrypts the plain password file and makes a backup"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# directory where the encrypted files are stored
KEYS_HOME="$HOME/data/personal/keys"

# openssl options (same option used in secret.sh to decrypt)
openssl_opt="-pbkdf2 -md md5 -aes-256-cbc -a -salt"

# add/change your remote location settings here.
remote_host=trex
remote_user=root
remote_path="/root/kanakku"
remote_scp_path="$remote_user@$remote_host:$remote_path"
remote_host2=eagle
remote_user2=arul
remote_path2="/Users/arul/data/personal/keys"
remote_scp_path2="$remote_user2@$remote_host2:$remote_path2"
remote_host3=penguin
remote_user3=arul
remote_path3="/home/arul/data/personal/keys"
remote_scp_path3="$remote_user3@$remote_host3:$remote_path3"
aruls_phone="arulspixel7"

# additional storage to veracrypt (or other encrypted volumes)
veracrypt_mount="/mnt/veracrypt"
veracrypt_bin="/usr/bin/veracrypt"

# filenames to use
encFileName=kanakku.txt.enc
encFileNameGpg=kanakku.txt.gpg
encFileNameYubi=kanakku.txt.yubi
plainFile=$1

# receipient keys for PGP (arul, deepak, yubikey usb 5C)
arul_keyid=451A1B6C
arul_work_keyid=F81609CB
deepak_keyid=091CB3D0
usbc_key=2D511E41

# gpg keys to encrypt with gpg.
gpg_opt="-qe -r $arul_keyid -r $arul_work_keyid -r $deepak_keyid -o $encFileNameGpg"
srm=""

init_osenv() {
  if [ $os_name = "Darwin" ] ; then
    veracrypt_mount="$HOME/mnt/veracrypt"
    veracrypt_bin="/Applications/VeraCrypt.app/Contents/MacOS/VeraCrypt"
    srm="rm -P"
  elif [ ! -f /usr/bin/srm ]; then
    srm="rm"
  else
    srm="srm"
  fi
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile
init_osenv

if [ -z $plainFile ]; then
  log.error "Usage: $my_name <plainFileToEncrypt>"
  exit 1
fi

if [ ! -f $plainFile ]; then
  log.error "Error: The plain file '$plainFile' does not exists or readable"
  exit 2
fi

if [ ! -d $KEYS_HOME ] ; then
  log.error "Error: KEYS_HOME=$KEYS_HOME does not exists!"
  exit 3
fi

cd $KEYS_HOME || exit 1
if [ ! -f $encFileName ]; then
  log.error "Error: $encFileName not present for backup, bailing out..."
  exit 4
fi

# backup the existing file
log.stat "Backing up the existing..."
cp $encFileName $encFileName.backup
cp $encFileNameYubi $encFileNameYubi.backup
cp $encFileNameGpg $encFileNameGpg.backup

# encrypt w/ openssl (enforce digest to md5 since different openssl libs default differently
# Note: make sure to add -md md5 on decription and not rely on defaults.
log.stat "Encrypting w/ openssl ..."
openssl enc -e $openssl_opt -in $plainFile -out $encFileName

# encrypt w/ yubi key ($usbc_key)
log.stat "Encrypting w/ Yubi Key USBC ($usbc_key) ..."
cat $plainFile |gpg -ae -r $usbc_key > $encFileNameYubi

# finally enrypt w/ gpg
log.stat "Encrypting w/ gpg ..."
gpg $gpg_opt $plainFile 2>&1 >> $my_logfile

# backup to remote scp path (first check if server is available)
log.stat "Checking remote server '$remote_host' is available to backup ..."
/sbin/ping -t30 -c1 -qo $remote_host >/dev/null 2>&1
if [ $? -eq 0 ]; then
  log.stat "Backing up to remote host at '$remote_scp_path'"
  scp $encFileName $encFileName.backup $encFileNameYubi $encFileNameYubi.backup $encFileNameGpg $encFileNameGpg.backup $remote_scp_path/.
else
  log.warn "$remote_host not available, skipping ..."
fi

# if second remote host available, backup there as well.
log.stat "Checking remote server '$remote_host2' is available to backup ..."
/sbin/ping -t30 -c1 -qo $remote_host2 >/dev/null 2>&1
if [ $? -eq 0 ]; then
  log.stat "Backing up to remote host at '$remote_scp_path2'" 
  scp $encFileName $encFileName.backup $encFileNameYubi $encFileNameYubi.backup $encFileNameGpg $encFileNameGpg.backup $remote_scp_path2/.
else
  log.warn "$remote_host2 not available, skipping ..."
fi

# if third remote host available, backup there as well.
log.stat "Checking remote server '$remote_host3' is available to backup ..."
/sbin/ping -t30 -c1 -qo $remote_host3 >/dev/null 2>&1
if [ $? -eq 0 ]; then
  log.stat "backing up to remote host at '$remote_scp_path3'"
  scp -P55522 $encFileName $encFileName.backup $encFileNameYubi $encFileNameYubi.backup $encFileNameGpg $encFileNameGpg.backup $remote_scp_path3/.
else
  log.warn "$remote_host3 not available, skipping ..."
fi

# see if we have veracrypt volume mounted, if so copy there as well
log.stat "Checking for veracrypt volume mounted, if copy there including plaintext file ..."
$veracrypt_bin -t -l 2>&1 > /dev/null
if [ $? -eq 0 ]; then
  log.stat "backing up to '$veracrypt_mount'"
  cp $plainFile $encFileName $encFileName.backup $encFileNameYubi $encFileNameYubi.backup $encFileNameGpg $encFileNameGpg.backup $veracrypt_mount/.
else
  log.warn "$veracrypt_mount not available, skipping ..."  
fi

# finally, if we have the arulspixel7 phone connected to adb, push it there as well
adb devices|awk 'NR>1 {print $1}'|grep $aruls_phone
if [ $? -eq 0 ]; then
  log.stat "backing up to $aruls_phone ..."
  $scripts_github/andriod/adb_push.sh -s $aruls_phone -f $encFileName -d /sdcard/data/docs
else
  log.warn "$aruls_phone is not available, skipping ..."
fi

# secure erase the plain file
log.stat "Secure erasing plainfile '$plainFile'"
$srm $plainFile
