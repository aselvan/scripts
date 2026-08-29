#!/usr/bin/env bash
################################################################################
# age.sh --- Simple age wrapper script
#
#   This script is a wrapper over age & age-plugin-youbikey external binaries 
#   to provide enc/dec functionality protecting sensitive files using Yubikey 
#   PIV applet. In addition, this can also be used to enc/dec using a 
#   symetrical passphrase if you don't have YubiKey or a YubiKey that has PIV
#   applet support.
#
# PreReq: age, age-plugin-yubikey binaries as well as YubiKey with PIV applet
#
# Author:  Arul Selvan
# Created: Aug 29, 2026
#
################################################################################
#
# Version History: (original & last 3)
#   Aug 29, 2026 --- Original version
################################################################################

# version format YY.MM.DD
version=26.08.29
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Simple age wrapper script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
login_db_file="/tmp/$(echo $my_name|cut -d. -f1).db"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# identity file - age looks for AGE_IDENTITY_FILE env, if it is not set
# the identity file (USBc Yubikey) will be used.
age_identity_file=${AGE_IDENTITY_FILE:-$HOME/data/personal/keys/age/yubikey_usbc_age.id}
op=""

# commandline options
options="e:d:r:o:i:svh?"
fname=""
receipients=()
output_fname=""
symetrical=0

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -e <file>       ---> encrypt the plain file, default output is file.age
  -d <file>       ---> decrypt the .age file
  -r <receipient> ---> Yubikey receipient pub key
  -i <id_file>    ---> Yubikey identity file [Default: value of env variable AGE_IDENTITY_FILE]
  -s              ---> Symetric enc/dec with passphrase instead of YubiKey, will prompt.
  -o <output>     ---> Outputfile for enc, default will be <file>.age
  -v              ---> enable verbose, otherwise just errors are printed
  -h              ---> print usage/help

Examples: 
  $my_name -e secret.txt -r age1yubikey1qgg2jlgk... -o <outputfile> # default will be secret.txt.age
  $my_name -d secret.txt.age -o <output_file> 
  $my_name -e secret.txt.age -o <output_file> -p secret_passphrase  # symetrical enc w/ out YubiKey
  $my_name -d secret.txt.age -o <output_file> -p secret_passphrase  # symetrical dec w/ out Yubikey

EOF
  exit 0
}

check_id_file() {
  # check and make sure identity file is available
  if [ ! -f $age_identity_file ] ; then
    log.error "YubiKey identity file is missing or non-existent ($age_identity_file)"
    usage
  fi
}

enc_file() {
  if [ ! -f $fname ] ; then
    log.error "File name to encrypt is non-existent!"
    usage
  fi

  # check output file name, otherwise default to input.age
  if [ -z "$output_fname" ] ; then
    output_fname="${fname}.age"
  fi

  log.stat "Encrypting file: $fname"

  # symetrical encryption? otherwise YubiKey
  if [ $symetrical -eq 1 ] ; then
    log.stat "Encryption Method: symetric [enter password when prompted]" 
    age -e -p -o $output_fname $fname
  else
    if [[ -z "${receipients[*]}" ]]; then
      log.error "No YubiKey recipients specified, see usage below"
      usage
    fi
    check_id_file
    log.stat "Encryption Method: YubiKey"
    age -e "${receipients[@]}" -i $age_identity_file -o $output_fname $fname
  fi
  log.stat "Enrypted file is at: $output_fname"
}

dec_file() {
  if [ ! -f $fname ] ; then
    log.error "File name to decrypt is non-existent!"
    usage
  fi

  # check required output file name 
  if [ -z "$output_fname" ] ; then
    log.error "Output file name is required!"    
    usage
  fi

  #determine if the encryption is by YubiKey or passphrase
  header=$(head -n 3 "$fname")
  if [[ "$header" == *"piv-p256"* ]] || [[ "$header" == *"yubikey"* ]]; then
    check_id_file
    log.stat "Encryption Type: YubiKey (Hardware Token)"
    log.stat "Decrypting file: $fname"
    log.stat "Touch the Yubikey to decrypt"
    age -i $age_identity_file -d -o $output_fname $fname
  else 
    log.stat "Encryption Type: Symetric"
    log.stat "Decrypting file: $fname"
    age -d -o $output_fname $fname
  fi
  log.stat "Decrypted file is at: $output_fname"
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

# ensure we have age installed
check_installed age
check_installed age-plugin-yubikey

# failfast -- cant do this now as there are multiple places variables are unbound!
#set -euo pipefail

# parse commandline options
while getopts $options opt ; do
  case $opt in
    r)
      receipients+=(-r $OPTARG )
      ;;
    e)
      fname="$OPTARG"
      op=enc
      ;;
    d)
      fname="$OPTARG"
      op=dec
      
      ;;
    s)
      symetrical=1
      ;;
    o)
      output_fname="$OPTARG"
      ;;
    i)
      age_identity_file="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

case $op in 
  enc)
    enc_file
    ;;
  dec)
    dec_file
    ;;
  *)
    usage
    ;;
esac

