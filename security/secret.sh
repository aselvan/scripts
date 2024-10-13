#!/usr/bin/env bash
#
# secret.sh --- convenient wrapper to view/search sensitive data in an encrypted file
#
# prereq: encrypted secret text file either with openssl and/or gpg already exists to 
#         read and search from in the directory specified in KEYS_HOME variable below.
#
# See also: enc_account.sh in this directory to encrypt a secret file
# 
# Author:  Arul Selvan
# Version: Feb 20, 2021 
#
# Version History
#   Feb 20, 2021  --- original version
#   Oct 13, 2024  --- Fixed logic so alternate key type i.e. openssl works, use standard logging
#

# version format YY.MM.DD
version=24.10.13
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Decrypt/View encrypted secret file content"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

# commandline options
options="s:iveh"

do_log=0
operation="view"
encFileBaseName="kanakku.txt"
search_string=""
gpg_opt="-qd"
openssl_opt="-pbkdf2 -md md5 -aes-256-cbc -a -salt"
egrep_opt=""
default_keys_home="$HOME/data/personal/keys"
KEYS_HOME=${KEYS_HOME:-$default_keys_home}

usage() {
  cat <<EOF
$my_title

Usage: $my_name [options]
  -s <string> ---> decrypt and regex case-sensitive search for 'string'
  -i          ---> search will be case-insensitive
  -e          ---> decrypt and open the file w/ vi editor in view mode.
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -i -s foobar
example: $my_name -e 

EOF
  exit
}

# validate path, file etc.
do_check() {

  # check keys_home directory
  log.info "Using KEYS_HOME=$KEYS_HOME"
  if [ ! -d $KEYS_HOME ] ; then
    log.error "KEYS_HOME=$KEYS_HOME does not exists!"
    exit 1
  fi

  # check enc files presense
  cd $KEYS_HOME || exit 2
  if [ ! -f ${encFileBaseName}.enc ] && [ ! -f ${encFileBaseName}.gpg ] ; then
    log.error "missing encrypted file(s) [$encFileBaseName.enc or $encFileBaseName.gpg]"
    usage
  fi
}

do_view() {
  # prefere GPG if exists
  if [ -f $encFileBaseName.gpg ] ; then
    log.info "decrypting $encFileBaseName.gpg for view ..."
    gpg $gpg_opt $encFileBaseName.gpg | view -
  else
    log.info "decrypting $encFileBaseName.enc for view ..."
    openssl enc -d $openssl_opt -in $encFileBaseName.enc | view -
  fi
  exit
}

do_search() {
  if [ -z "$search_string" ] ; then
    log.info "search string is missing!"
    usage
  fi
  # prefere GPG if exists
  if [ -f $encFileBaseName.gpg ] ; then
    log.info "decrypting $encFileBaseName.gpg for search ..."
    echo
    gpg $gpg_opt $encFileBaseName.gpg | egrep $egrep_opt $search_string
  else
    echo
    log.info "decrypting $encFileBaseName.enc for search ..."
    openssl enc -d $openssl_opt -in $encFileBaseName.enc | egrep $egrep_opt $search_string
  fi
  exit
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# commandline parse
while getopts $options opt; do
  case $opt in
    s)
      search_string=$OPTARG
      operation="search"
      ;;
    i)
      egrep_opt="-i"
      ;;
    e)
      operation="view"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
    esac
done

do_check

if [ $operation = "view" ] ; then
  do_view
else
  do_search
fi
