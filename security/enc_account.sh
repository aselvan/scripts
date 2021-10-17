#!/bin/sh
#
# enc_account.sh --- encrypts the account password plain file and makes a backup 
# to remote ssh path.
#
# Note: this encypts the plain file w/ both openssl (symetric) and gpg (PKI) 
# createing 2 files.
#
# Author:  Arul Selvan
# Version: Dec 26, 2018
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

# directory where the encrypted files are stored
KEYS_HOME="$HOME/data/personal/keys"
my_name=`basename $0`

# add/change your remote location settings here.
remote_host=trex
remote_user=root
remote_path="/root/kanakku"
remote_scp_path="$remote_user@$remote_host:$remote_path"
encFileName=kanakku.txt.enc
encFileNameGpg=kanakku.txt.gpg
encFileNameYubi=kanakku.txt.yubi
plainFile=$1

# receipient keys for PGP (arul,deepak...)
arul_keyid=451A1B6C
arul_work_keyid=F81609CB
deepak_keyid=091CB3D0

# gpg keys to encrypt with gpg.
gpg_opt="-qe -r $arul_keyid -r $arul_work_keyid -r $deepak_keyid -o $encFileNameGpg"

echo "[INFO] $my_name starting ... " | tee $log_file

if [ -z $plainFile ]; then
  echo "Usage: $my_name <plainFileToEncrypt>" | tee -a $log_file
  exit 1
fi

if [ ! -f $plainFile ]; then
  echo "[ERROR] The plain file '$plainFile' does not exists or readable" | tee -a $log_file
  exit 2
fi

echo "[INFO] $0 starting ..."
if [ ! -d $KEYS_HOME ] ; then
  echo "[ERROR] KEYS_HOME=$KEYS_HOME does not exists!" | tee -a $log_file
  exit 3
fi

cd $KEYS_HOME || exit 1
if [ ! -f $encFileName ]; then
  echo "[WARN] $encFileName not present for backup, bailing out..." | tee -a $log_file
  exit 4
fi

# backup the existing file
echo "[INFO] backing up the existing..." | tee -a $log_file
cp $encFileName $encFileName.backup
cp $encFileNameYubi $encFileNameYubi.backup
cp $encFileNameGpg $encFileNameGpg.backup

# NOTE: disabled copying to gDrive as google already proved making mistake by 
# sending gdrive data to other people.
#rclone copyto $encFileName.backup root:/home/personal/$encFileName.backup
#rclone copyto $encFileNameYubi.backup root:/home/personal/$encFileNameYubi.backup

# encrypt w/ openssl
echo "[INFO] encrypting w/ openssl ..." | tee -a $log_file
openssl aes-256-cbc -a -salt -in $plainFile -out $encFileName

# encrypt w/ yubi key
echo "[INFO] encrypting w/ Yubi Key ..." | tee -a $log_file
#cat $plainFile |gpg -ae -r 0E2A2DE0 > $encFileNameYubi
cat $plainFile |gpg -ae -r 0x72A50CEF > $encFileNameYubi

# finally enrypt w/ gpg
echo "[INFO] encrypting w/ gpg ..." | tee -a $log_file
gpg $gpg_opt $plainFile 2>&1 | tee -a $log_file

# backup
#echo "[INFO] Copying to gdrive"
# NOTE: disable copying to gDrive as google already proved making mistake by 
# sending people data to others.
#rclone copyto $encFileName root:/home/personal/$encFileName
#rclone copyto $encFileNameYubi root:/home/personal/$encFileNameYubi

# backup to remote scp path (first check if server is available)
echo "[INFO] checking remote server '$remote_host' is available to backup ..." | tee -a $log_file
/sbin/ping -t30 -c1 -qo $remote_host >/dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "[ERROR] $remote_host not available, exiting..." | tee -a $log_file
   exit
fi
echo "[INFO] backing up to remote host at '$remote_scp_path'" | tee -a $log_file
scp $encFileName $encFileName.backup $encFileNameYubi $encFileNameYubi.backup $encFileNameGpg $encFileNameGpg.backup $remote_scp_path/.

# secure erase the plain file
echo "[INFO] Secure erasing plainfile '$plainFile'" | tee -a $log_file
rm -P $plainFile
