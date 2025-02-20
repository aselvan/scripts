#!/usr/bin/env bash
################################################################################
#
# keychain.sh --- Store/Retrive passwords in native MacOS keychain
#
# This script creates a separate keychain to add/delete/view passwords. This
# can be used to store any thing leveraging Apple secret store, comes handy 
# to store stuff that is not available to mac applications. The keystore file
# will be in $HOME/Library/Keychains/$USER.keychain-db. The Apple keychain 
# app is unaware so you have to add (i.e. open) this file once to see it in 
# the keychain app which is not necessary or needed for this script to work.
#
# Note: by default keychain file will be named after your username ($USER)
#
# Author:  Arul Selvan
# Created: Jul 30, 2022
#
################################################################################
# Version History:
#   July 30, 2022 --- Original version
#   Feb  20, 2025 --- Use standard includes and copy password to pastebuffer
# 
################################################################################

# version format YY.MM.DD
version=25.02.20
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Store/Retrive passwords in native MacOS keychain"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="k:c:w:u:p:t:vh?"

keychain_file_name="${USER}"
keychain_file_path="${HOME}/Library/Keychains/${keychain_file_name}.keychain-db"
website=""
username=""
password=""
action=""
comment="Password added by $my_version"
command_name=""
supported_commands="add|show|delete|showall"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -k <keychain> ---> name to create a separate keychain store [default: $keychain_file_name]
  -c <command>  ---> command to run [see supported commands below] 
  -w <website>  ---> website name for which your user/password applies [example: yahoo.com]
  -u <username  ---> The username to store [note: you can have multiple usernames for same website]
  -p <password> ---> The password to store
  -t <message>  ---> a quoted string [example: "username/password for website yahoo.com"]
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

Supported commands: $supported_commands

example(s): 
  $my_name -c add -w yahoo.com -u foobar -p password123 -t "Yahoo password entry"
  $my_name -c show -w yahoo.com -u foobar
  $my_name -c delete -w yahoo.com -u foobar
  
EOF
  exit 0
}

check_args() {
  if [ -z $command_name ] ; then
    log.error "missing required argument i.e. command. See usage below"
    usage
  fi
  if [ -z $website ] ; then
    log.error "missing required argument! i.e. website. See usage below"
    usage
  fi
  if [ -z $username ] ; then
    log.error "missing required argument! i.e. username. See usage below"
    usage
  fi
}

do_add() {
  if [ -z $password ] ; then
    log.error "missing required argument! i.e. password. See usage below"
    usage
  fi
  log.stat "Adding password for website/username: $website/$username"
  security add-generic-password -j "$comment" -s $website -a $username -w $password $keychain_file_name.keychain
  if [ $? -ne 0 ] ; then
    log.error "Error adding $wesite/$username key!"
  else
    log.stat "The specifed entry is added"
  fi

}

do_delete() {
  log.stat "Deleting entry for website/username: $website/$username"
  security delete-generic-password -s $website -a $username $keychain_file_name.keychain >>$my_logfile 2>&1
  if [ $? -ne 0 ] ; then
    log.error "Error deleting $website/$username key. Are you sure the key is correct?"
  fi
}

do_show() {
  local passwd=`security find-generic-password -s $website -a $username -w $keychain_file_name.keychain 2>>$my_logfile`
  if [ ! -z "$passwd" ] ; then
    log.stat "Password for $website/$username is: '$passwd'. For convenience, also copied to pastebuffer."
    echo $passwd|pbcopy
  else
    log.error "The key $website/$username not found in keychain, check and try again"
  fi
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

if [ "$os_name" != "Darwin" ] ; then
  log.error "error" "This script is for MacOS only!"
  exit 0
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    k)
      keychain_file_name="$OPTARG"
      keychain_file_path="${HOME}/Library/Keychains/${keychain_file_name}.keychain-db"
      ;;
    c)
      command_name="$OPTARG"
      ;;
    w)
      website="$OPTARG"
      ;;
    u)
      username="$OPTARG"
      ;;
    p)
      password="$OPTARG"
      ;;
    t)
      comment="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
     ?|h|*)
      usage
      ;;
  esac
done

# validate we have all the args we need.
check_args

# check if keychain file already created and create if not present
if [ ! -f $keychain_file_path ] ; then
  log.stat "Enter a password for your keychain when prompted to continue ..."
  security create-keychain ${keychain_file_name}.keychain
fi

case $command_name in 
  add)
    do_add
    ;;
  delete)
    do_delete
    ;;
  show)
    do_show 
    ;;
  *)
    log.error "Invalid command! See usage for valid commands"
    usage
    ;;
esac
