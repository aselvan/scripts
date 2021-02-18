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
options="a:k:t:h"
secret=""
file=""
add=0
op_type=""
secret_file_dir="$HOME/.oathtool"
os_name=`uname -s`
name=`basename $0`

# encyption type/tool (default is gpg w/ default key)
enc_type=gpg

# ctrl+c handler
function ctrl_c() {
  echo ""
  echo "[INFO] $name exiting."
  exit
}

# print usage
function usage() {
  cat <<EOF
  
USAGE: $name -k <name> | -a <secret> -k <name> [-t <type>] 
  
  -k <name>   is the name of the file stored under $secret_file_dir directory that contains the secret key
  -a <secret> content of secret key to be encrypted and stored by the <name> under $secret_file_dir
  -t <type>   encryption tool or type, values can be gpg or openssl [default: gpg]

  example: $name -k gmail  
  example: $name -a 'sfwedfv835sdfjf453' -k gmail [-t openssl]

EOF
  exit
}

add() {
  # encrypt and store the secret key
  if [[ -z $secret || -z $file ]]; then
    echo "[ERROR] either secret or name is missing"
    usage
  fi

  # just create the ~/.oathtool directory if it does not already exist
  if [ ! -f $secret_file_dir ]; then
   mkdir -p $secret_file_dir || exit
  fi

  # create based on type (gpg or openssl)
  if [ $enc_type = "gpg" ] ; then
    dummy=$(echo $secret | gpg -eaq >$secret_file_dir/$file.gpg)
    if [ $? -ne 0 ]; then
      echo "[ERROR] encrypting secret key, try again ..."
      exit
    fi
  elif [ $enc_type = "openssl" ] ; then
    dummy=$(echo $secret | openssl enc -aes-256-cbc -a -salt >$secret_file_dir/$file)
    if [ $? -ne 0 ]; then
      echo "[ERROR] encrypting secret key, try again ..."
      exit
    fi
  else
    echo "[ERROR] invalid encryption type: $enc_type"
    usage
  fi
  echo "[INFO] encrypted secret key at $secret_file_dir/$file"
}

get() {
  # get OTP based on secret
  if [[ ! -f $secret_file_dir/$file && ! -f $secret_file_dir/$file.gpg  ]]; then
    echo "[ERROR] encrypted secret key file missing, check $secret_file_dir/$file[.gpg]"
    exit
  fi

  # based on file type, use the correct encryption tool.
  if [ -f $secret_file_dir/$file.gpg ] ; then
    decrypted_key=$(gpg -qd $secret_file_dir/$file.gpg)
  else
    decrypted_key=$(cat $secret_file_dir/$file|openssl enc -d -aes-256-cbc -a)
  fi

  # validate the decrypted key
  if [ $? -ne 0 ]; then
    echo "[ERROR] decrypting secret key, check your password and try again"
    exit
  fi
  if [ -z $decrypted_key ]; then
    echo "[ERROR] decrypted key is empty: $decrypted_key"
    exit
  fi

  # go in a loop and continue to copy the key to paste buffer until 120 sec  
  echo "[INFO] OTP is continually copied to paste buffer for 2 minutes, Ctrl+c to quit"
  for (( i=0; i<120; i++)) do
    echo -n "."
    oathtool --totp -b $decrypted_key | tr -d '\n' | $pbc
    sleep 1
  done
  echo ""
  echo "[INFO] $name completed."
}


# ----------- main entry -----------
# pastebuffer depending on OS
if [ $os_name = "Darwin" ]; then
  pbc='pbcopy'
else
  pbc='xsel --clipboard --input'
fi

# commandline parse
while getopts $options opt; do
  case $opt in
    k)
      file=$OPTARG
      ;;
    t)
      enc_type=$OPTARG
      ;;
    a)
      secret=$OPTARG
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

if [[ -z $file && -z $secret ]]; then
  echo "[ERROR] missing arguments!"
  usage
fi

# install ctrl+c handler
trap ctrl_c INT

# add or get
if [[ ! -z $secret && ! -z $file ]] ; then
  add
elif [ ! -z $file ] ; then
  get
else
  usage
fi
