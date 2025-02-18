#!/usr/bin/env bash
##################################################################################
# oathtool.sh --- oathtool wrapper to keep the secret keys in encrypted form.
#
# The script uses the encrypted secret keys and generates TOTP passwords and directly 
# copies to the paste buffer continually as the key changes every 30 sec allowing you
# to simply Ctrl+v (linux) or Command+ (macOS) to the browser or other apps that needs
# the OTP code. No need to grab the phone, and get the code and type it in.
#
# preq: oath-toolkit, openssl, tr (should be available on base install)
#   Mac:   brew install oath-toolkit openssl qrencode zbar
#   Linux: apt-get install oathtool xsel qrdecode zbar-tools
#
# Author:  Arul Selvan
# Version: Feb 8, 2020 
##################################################################################
#
# Version History:
#   Feb 8,  2020  --- Original Version
#   Feb 17, 2025  --- Use standard functions, show code to console etc.
#
##################################################################################


# version format YY.MM.DD
version=25.02.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="oathtool wrapper to keep the secret keys in encrypted form"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="a:k:t:h"

oathtool_opt="--totp -b"
secret=""
file=""
secret_file_dir="$HOME/.oathtool"
base32_error="base32 decoding failed"
# how long to copy continually
ttl=90
otp=0
potp=0
sec_left=30

# encyption type/tool (default is gpg w/ default key)
enc_type=gpg

# print usage
function usage() {
  cat <<EOF
$my_name --- $my_title

Usage: $my_name [options]

  -k <name>   ---> name of the secret key file stored under $secret_file_dir directory
  -a <secret> ---> content of secret key
  -t <type>   ---> encryption type, values can be gpg or openssl [Default: $enc_type]

Examples:
  # generate TOTP code and copy to paste buffer for the secret under the key 'gmail'
  $name -k gmail
  
  # adds the secret under the key 'gmail'
  $name -k gmail -a 'sfwedfv835sdfjf453'

  # extract the secret from my_gmail_qrcode_image.png and adds to keystore.
  $name -k gmail -a \$(zbarimg -q my_gmail_qrcode_image.png |awk -F':' '{print $2;}')

EOF
  exit
}

add() {
  # encrypt and store the secret key
  if [[ -z $secret || -z $file ]]; then
    log.error "either secret or name is missing"
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
      log.error "encrypting secret key, try again ..."
      exit
    fi
  elif [ $enc_type = "openssl" ] ; then
    dummy=$(echo $secret | openssl enc -aes-256-cbc -a -salt >$secret_file_dir/$file)
    if [ $? -ne 0 ]; then
      log.error "encrypting secret key, try again ..."
      exit
    fi
  else
    log.error "invalid encryption type: $enc_type"
    usage
  fi
  log.stat "encrypted secret key at $secret_file_dir/$file"
}

get() {
  # get OTP based on secret
  if [[ ! -f $secret_file_dir/$file && ! -f $secret_file_dir/$file.gpg  ]]; then
    log.error "encrypted secret key file missing, check $secret_file_dir/$file[.gpg]"
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
    log.error "decrypting secret key, check your password and try again"
    exit
  fi
  if [ -z $decrypted_key ]; then
    log.error "decrypted key is empty: $decrypted_key"
    exit
  fi

  # go in a loop and continue to copy the key to paste buffer until $ttl sec  
  log.stat "OTP is continually copied to paste buffer for $ttl seconds, Ctrl+c to quit"

  # check once to determine if the key is hex or base32
  # Note: Symentac VIPAccess key is hex and google & others are base32 encoded
  oathtool_err=`oathtool $oathtool_opt $decrypted_key 2>&1 >/dev/null`
  if [[ "$oathtool_err" == *"$base32_error"* ]] ; then
    log.warn "secret key is not base32 encoded, adjusting oathtool option."
    oathtool_opt="--totp"
  fi

  # loop for $ttl min and generate code and copy to paste buffer.
  for (( i=0; i<$ttl; i++)) do
    otp=$(oathtool $oathtool_opt $decrypted_key | tr -d '\n')
    # save to paste buffer
    echo $otp|$pbc
    
    if [ $potp -eq 0 ] ; then
      potp=$otp
    fi
    if [ $potp -ne $otp ] ; then
      potp=$otp
      sec_left=30
    else
      let sec_left--
    fi
    
    # display on console as well
    echo -ne  "\r  OTP: $otp  |  Time Left: $sec_left sec(s)"
    sleep 1
  done
  echo ""
}


# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

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

# install ctrl+c handler
trap signal_handler INT

# add or get
if [[ ! -z $secret && ! -z $file ]] ; then
  add
elif [ ! -z $file ] ; then
  get
else
  usage
fi
