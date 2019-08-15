#!/bin/sh

#
# enc_account.sh --- encrypts the account password file and backup to gDrive etc.
#
# Author:  Arul Selvan
# Version: Dec 26, 2018
#

# directory where the encrypted files are stored
KEYS_HOME=/data/personal/keys
encFileName=enc.txt.enc
encFileNameYubi=enc.txt.yubi
plainFile=$1

if [ -z $plainFile ]; then
  echo "Usage: $0 <plainFileToEncrypt>"
  exit 1
fi

if [ ! -f $plainFile ]; then
  echo "[ERROR] The plain file '$plainFile' does not exists or readable"
  exit 2
fi

echo "[INFO] $0 starting ..."
if [ ! -d $KEYS_HOME ] ; then
  echo "[ERROR] KEYS_HOME=$KEYS_HOME does not exists!"
  exit 3
fi

cd $KEYS_HOME || exit 1
if [ ! -f $encFileName ]; then
  echo "[WARN] $encFileName not present for backup, bailing out..."
  exit 4
fi

# backup the existing file
echo "[INFO] backing up the existing..."
cp $encFileName $encFileName.backup
cp $encFileNameYubi $encFileNameYubi.backup
rclone copyto $encFileName.backup root:/home/personal/$encFileName.backup
rclone copyto $encFileNameYubi.backup root:/home/personal/$encFileNameYubi.backup

# encrypt w/ openssl
echo "[INFO] encrypting w/ openssl ..."
openssl aes-256-cbc -a -salt -in $plainFile -out $encFileName

# encrypt w/ yubi key
echo "[INFO] encrypting w/ Yubi Key ..."
cat $plainFile |gpg -ae -r 0E2A2DE0 > $encFileNameYubi

# backup
echo "[INFO] Copying to gdrive"
rclone copyto $encFileName root:/home/personal/$encFileName
rclone copyto $encFileNameYubi root:/home/personal/$encFileNameYubi

# secure erase the plain file
echo "[INFO] Secure erasing plainfile '$plainFile'"
rm -P $plainFile
