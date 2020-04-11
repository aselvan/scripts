#!/bin/bash
#
# add_ssh_pubkey.sh - script to append the public key to authorized_keys for keybased login
#
# note: ssh-copy-id does the same thing but it doesn't consistenly work on all systems.
# 
# Author:  Arul Selvan
# Version: Dec 8, 2014
#
user=""
host=""
my_pub_key=`cat ~/.ssh/id_rsa.pub`

while getopts ":u:h:" opt; do
  case $opt in 
    u)
      user=$OPTARG
      ;;
    h) 
      host=$OPTARG
      ;;
  esac
done

if [ -z $user ] || [ -z $host ] ; then
   echo "Usage: $0 -h <hostname> -u <username>"
   exit
fi

echo "[INFO] Adding key to remote host: $user@$host ..."
remote_command="echo \"$my_pub_key\" >> .ssh/authorized_keys" 
ssh $user@$host $remote_command
