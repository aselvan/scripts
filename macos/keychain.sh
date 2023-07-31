#!/usr/bin/env bash
#
# keychain.sh --- store and retrive passwords in native MacOS keychain
#
# This script creates a separate keychain to add/delete/view passwords. This
# can be used to store any thing leveraging Apple secret store, comes handy 
# to store stuff that is not available to mac applications. The keystore file
# will be in $HOME/Library/Keychains/$USER.keychain-db. The Apple keychain 
# app is unaware so you have to add (open) this file once to see it in the 
# keychain app which is not necessary or needed for this script to work.
#
# Note: by default keychain file will be named after your username ($USER)
#
# Author:  Arul Selvan
# Created: Jul 30, 2022
#

# version format YY.MM.DD
version=23.07.30
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
options="k:a:w:u:p:c:vh?"
verbose=0
keychain_file_name="${USER}"
keychain_file_path="${HOME}/Library/Keychains/${keychain_file_name}.keychain-db"
website=""
username=""
password=""
action=""
comment="Password added by $my_version"
# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -k <keychain> ---> name to create a separate keychain store [default: $keychain_file_name]
     -a <action>   ---> Action is one of "add" or "delete" "show"
     -w <website>  ---> website name for which your user/password applies [example: yahoo.com]
     -u <username  ---> The username to store
     -p <password> ---> The password to store
     -c <comment>  ---> Quoted comment string [example: "account details for yahoo.com"]
     -v            ---> verbose mode prints info messages, otherwise just errors are printed
     -h            ---> print usage/help

  example: $my_name -a add -w yahoo.com -u foobar -p password123
  example: $my_name -a show -w yahoo.com -u foobar
  example: $my_name -a delete -w yahoo.com -u foobar
  
EOF
  exit 0
}

log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}

log.stat() {
  log.init
  local msg=$1
  echo -e "\e[0;34m$msg\e[0m" | tee -a $log_file 
}

log.warn() {
  log.init
  local msg=$1
  echo -e "\e[1;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[1;31m$msg\e[0m" | tee -a $log_file 
}

check_args() {
  if [ -z $action ] ; then
    log.error "missing required argument 'action'! See usage"
    usage
  fi
  if [ -z $website ] ; then
    log.error "missing required argument 'website'! See usage"
    usage
  fi
  if [ -z $username ] ; then
    log.error "missing required argument 'username'! See usage"
    usage
  fi
}

# ----------  main --------------
log.init
if [ "$os_name" != "Darwin" ] ; then
  log.error "error" "This script is for MacOS only!"
  exit 1
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    k)
      keychain_file_name="$OPTARG"
      keychain_file_path="${HOME}/Library/Keychains/${keychain_file_name}.keychain-db"
      ;;
    a)
      action="$OPTARG"
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
    c)
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

case $action in 
  add)
    if [ -z $password ] ; then
      log.error "missing required argument 'password'! See usage"
      usage
    fi
    log.stat "Adding password for website ($website) and username ($username) ..."
    security add-generic-password -j "$comment" -s $website -a $username -w $password $keychain_file_name.keychain
    ;;
  delete)
    log.stat "Deleting entry for website ($website) and username ($username) ..."
    security delete-generic-password -s $website -a $username $keychain_file_name.keychain
    ;;
  show)
    log.stat "Password for website ($website) and username ($username) is below"
    security find-generic-password -s $website -a $username -w $keychain_file_name.keychain    
    ;;
  *)
    log.error "Invalid action verb! See usage"
    usage
    ;;
esac
