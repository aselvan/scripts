#!/usr/bin/env bash
###############################################################################
# security.sh --- Wrapper for many useful security related commands
#
# Though these info are readily available with different commandline tools, 
# this script is a wrapper to get a simple output of all you need to know.
#
# Author:  Arul Selvan
# Created: Nov 27, 2024 
#
################################################################################
# Version History:
#   Nov 27, 2024 --- Original version
#   Mar 5,  2025 --- Supress additional char for pwgen, added openssl_opt
################################################################################

# version format YY.MM.DD
version=25.03.05
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper for many useful security related commands"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:l:f:bs::vh?"

command_name=""
supported_commands="pwgen|usergen|enc|dec|basicauth|unixhash"
pwgen_len=12
pwgen_len_fixed=3
enc_dec_file=""
user_password=""
password=""
usergen_len=8
usergen_supress_chars=",;{}[]o:#^+\|*()=-\"/\\.%&<>_'\`?"
pwgen_supress_chars="olO:#*()<>'\`\\"
suppress_chars=""
openssl_opt="-pbkdf2 -md md5 -aes-256-cbc -a -salt"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>  ---> command to run [see supported commands below]  
  -l <len>      ---> length of password for pwgen command
  -s <chars>    ---> list of chars to exclude from passwords
  -f <file>     ---> filename for enc/dec funcions
  -b <user:pwd> ---> used for basicauth to encode user/password in base64 encoding
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

Supported commands: 
  $supported_commands  

example(s): 
  $my_name -c pwgen
  $my_name -c pwgen -s "],-."
  $my_name -c enc -f /tmp/plain.txt
  $my_name -c dec -f /tmp/plain.txt [don't include .enc extension]

EOF
  exit 0
}

function do_pwgen() {
  check_installed pwgen
  local rnd_digit=$(( $RANDOM % 10 ))
  local abc=ABCDEFGHIJKLMNOPQRSTUVXWYZ
  local n=$(( $RANDOM %26 ))
  local rnd_char=${abc:$n:1}
  local len=$(($pwgen_len-$pwgen_len_fixed))
  local passwd="$rnd_digit`pwgen -cny --remove-chars="${pwgen_supress_chars}${suppress_chars}" $len 1`@$rnd_char"
  log.stat "\tStrong $(($len+$pwgen_len_fixed)) char password is: $passwd" $green
}

function do_usergen() {
  check_installed pwgen
  local uname=a`pwgen --remove-chars=${usergen_supress_chars}${suppress_chars} -cny $usergen_len 1`s
  log.stat "\tUsername: $uname" $green
}

function do_enc() {
  check_installed openssl
  if [ -z $enc_dec_file ] ; then
    log.error "Need filename to encrypt, see usage"
    usage
  fi
  openssl enc $openssl_opt -in $enc_dec_file > $enc_dec_file.enc
  log.stat "Encrypted file at: $enc_dec_file.enc"
}

function do_dec() {
  check_installed openssl
  if [ -z $enc_dec_file ] ; then
    log.error "Need filename to decrypt, see usage"
    usage
  fi
  if [ ! -f $enc_dec_file.enc ] ; then
    log.error "Can't find the encrypted file $enc_dec_file.enc ..."
    exit 2
  fi
  openssl enc -d $openssl_opt -in $enc_dec_file.enc > $enc_dec_file
  log.stat "Decrypted file at: $enc_dec_file"
}

function do_basicauth() {
  if [ -z $user_password ] ; then
    log.error "Need user:password to create basicauth, see usage"
    usage
  fi
  ba=$(echo -n "$user_password"|base64)  
  log.stat "\tBasic Auth: $ba"
}

function do_unixhash() {
  unix_hashed_password=`openssl passwd -1`
  log.stat "\tUnix hash of your password is: $unix_hashed_password"
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    l)
      pwgen_len="$OPTARG"
      ;;
    f)
      enc_dec_file="$OPTARG"
      ;;
    b)
      user_password="$OPTARG"
      ;;
    s)
      suppress_chars="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing arguments, see usage below"
  usage
fi

# run different wrappes depending on the command requested
case $command_name in
  pwgen)
    do_pwgen
    ;;
  usergen)
    do_usergen
    ;;
  enc)
    do_enc
    ;;
  dec)
    do_dec
    ;;
  basicauth)
    do_basicauth
    ;;
  unixhash)
    do_unixhash
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat  "Available commands: $supported_commands"
    exit 1
    ;;
esac

