#!/bin/sh
#
# enc_account.sh --- encrypts the account password plain file and makes a backup 
# to remote ssh path.
#
# Author:  Arul Selvan
# Version: Dec 26, 2018
#

# directory where the encrypted files are stored
KEYS_HOME="$HOME/data/personal/keys"
my_name=`basename $0`

# add/change your remote location settings here.
remote_host=aselvanrp
remote_user=aselvan
remote_path="/Users/aselvan/data/personal/encrypted"
remote_scp_path="$remote_user@$remote_host:$remote_path"
encFileName=kanakku.txt.enc
encFileNameYubi=kanakku.txt.yubi
plainFile=$1

if [ -z $plainFile ]; then
  echo "Usage: $my_name <plainFileToEncrypt>"
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

# NOTE: disabled copying to gDrive as google already proved making mistake by 
# sending people data to others.
#rclone copyto $encFileName.backup root:/home/personal/$encFileName.backup
#rclone copyto $encFileNameYubi.backup root:/home/personal/$encFileNameYubi.backup

# encrypt w/ openssl
echo "[INFO] encrypting w/ openssl ..."
openssl aes-256-cbc -a -salt -in $plainFile -out $encFileName

# encrypt w/ yubi key
echo "[INFO] encrypting w/ Yubi Key ..."
#cat $plainFile |gpg -ae -r 0E2A2DE0 > $encFileNameYubi
cat $plainFile |gpg -ae -r 0x72A50CEF > $encFileNameYubi

# backup
#echo "[INFO] Copying to gdrive"
# NOTE: disable copying to gDrive as google already proved making mistake by 
# sending people data to others.
#rclone copyto $encFileName root:/home/personal/$encFileName
#rclone copyto $encFileNameYubi root:/home/personal/$encFileNameYubi

# backup to remote scp path (first check if server is available)
echo "[INFO] checking remote server '$remote_host' is available to backup ..."
/sbin/ping -t30 -c1 -qo $remote_host >/dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "[ERROR] $remote_host not available, exiting..."
   exit
fi
echo "[INFO] backing up to remote host at '$remote_scp_path'"
scp $encFileName $encFileName.backup $encFileNameYubi $encFileNameYubi.backup $remote_scp_path/.

# secure erase the plain file
echo "[INFO] Secure erasing plainfile '$plainFile'"
rm -P $plainFile
