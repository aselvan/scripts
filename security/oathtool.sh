#!/bin/bash
#
#
# oathtool.sh --- simple wrapper over oathtool to keep the secret keys in encrypted form
#
# The script uses the encrupted secret keys and generates TOTP passwords and directly 
# copies to the paste buffer continually as the key changes every 30 sec allowing you
# to simply Ctrl+v (linux) or Command+ (macOS) to the browser or other apps that needs
# the OTP code. No need to grab the phone, and get the code and type it in.
#
# preq: oath-toolkit, openssl, tr (should be available on base install)
#   Mac:   brew install oath-toolkit openssl
#   Linux: apt-get install oathtool xsel
#
# Author:  Arul Selvan
# Version: Feb 8, 2020 
#

# oathtool args
oathtool_opt="--totp -b"
options="a:k:h"
secret=""
file=""
add=0
secret_file_dir="$HOME/.oathtool"
os_name=`uname -s`
name=`basename $0`

# ctrl+c handler
function ctrl_c() {
  echo ""
  echo "[INFO] $name exiting."
  exit
}

# print usage
function usage() {
  #clear
  cat <<EOF
  
USAGE: $name -k <name> | -a <secret> -k <name>
  
  <name>   is the name of the file stored under $secret_file_dir directory that contains the secret key
  <secret> content of secret key to be encrypted and stored by the <name> under $secret_file_dir
    
  example: $name -k gmail  
  example: $name -a 'ssddfv835sjf453' -k gmail

EOF
  exit
}

# ----------- main entry -----------
while getopts $options opt; do
  case $opt in
    k)
      file=$OPTARG
      ;;
    a)
      secret=$OPTARG
      add=1
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

# install ctrl+c handler
trap ctrl_c INT

# pastebuffer depending on OS
if [ $os_name = "Darwin" ]; then
  pbc='pbcopy'
else
  pbc='xsel --clipboard --input'
fi

# add or get
if [ $add -ne 0 ]; then
  # encrypt and store the secret key
  if [[ -z $secret || -z $file ]]; then
    echo "[ERROR] either secret or name is missing"
    usage
  fi

  # just create the ~/.oathtool directory if it does not already exist
  if [ ! -f $secret_file_dir ]; then
   mkdir -p $secret_file_dir || exit
  fi
  encrypted_key=$(echo $secret | openssl enc -aes-256-cbc -a -salt)
  if [ $? -ne 0 ]; then
    echo "[ERROR] encrypting secret key, try again"
    exit
  fi
  echo $encrypted_key > $secret_file_dir/$file
  echo "[INFO] encrypted secret key at $secret_file_dir/$file"
else
  # create a OTP
  if [ ! -f $secret_file_dir/$file ]; then
    echo "[ERROR] encrypted secret key file missing, check $secret_file_dir/$file"
    exit
  fi
  # go in a loop and continue to copy the key to paste buffer until 120 sec
  decrypted_key=$(cat $secret_file_dir/$file|openssl enc -d -aes-256-cbc -a)
  if [ $? -ne 0 ]; then
    echo "[ERROR] decrypting secret key, check your password and try again"
    exit
  fi
  if [ -z $decrypted_key ]; then
    echo "[ERROR] decrypted key is empty: $decrypted_key"
    exit
  fi
  echo "[INFO] OTP is continually copied to paste buffer for 2 minutes, Ctrl+c to quit"
  for (( i=0; i<120; i++)) do
    echo -n "."
    oathtool --totp -b $decrypted_key | tr -d '\n' | $pbc
    sleep 1
  done
  echo ""
  echo "[INFO] $name completed."
fi
