#!/bin/bash
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

os_name=`uname -s`
my_name=`basename $0`
options="s:vlh"

do_log=0
operation="view"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
encFileBaseName="kanakku.txt"
search_string=""
gpg_opt="-qd"
openssl_opt="enc -d -aes-256-cbc -a -in"
vi_bin="/usr/bin/view"

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -s <string> ==> decrypt and regex search for 'string' in the content
  -v          ==> decrypt and open the file w/ vi (view) [default view]
  -l          ==> log [default: no logging].

  example: $my_name -s foobar

EOF
  exit
}

log() {
  local msg=$1

  if [ $do_log -eq 0 ] ; then
    return
  fi
  echo $msg |tee -a $log_file
}

# validate path, file etc.
do_check() {
  # directory where the encrypted files are stored
  log "[INFO] checking KEYS_HOME in environment ..."
  if [ -z $KEYS_HOME ] ; then
    KEYS_HOME="$HOME/data/personal/keys"
    log "[INFO] KEYS_HOME not found, defaulting to $KEYS_HOME"
  else
    log "[INFO] KEYS_HOME is $KEYS_HOME"
  fi

  if [ ! -d $KEYS_HOME ] ; then
    log "[ERROR] KEYS_HOME=$KEYS_HOME does not exists!"
    exit 1
  fi
  cd $KEYS_HOME || exit 2
  if [[ ! -f $encFileBaseName.enc || ! -f $encFileBaseName.gpg ]] ; then
    log "[ERROR] missing encrypted file(s) [$encFileBaseName.enc or $encFileBaseName.gpg]"
    usage
  fi
  # reset vi_bin path on macOS
  if [ $os_name = "Darwin" ]; then
    vi_bin="/usr/local/bin/view"
  fi
}

do_view() {
  # prefere GPG if exists
  if [ -f $encFileBaseName.gpg ] ; then
    log "[INFO] decrypting $encFileBaseName.gpg for view ..."
    gpg $gpg_opt $encFileBaseName.gpg | $vi_bin -
  else
    log "[INFO] decrypting $encFileBaseName.enc for view ..."
    openssl $openssl_opt | $vi_bin -
  fi
  exit
}

do_search() {
  if [ -z $search_string ] ; then
    log "[ERROR] search string is missing!"
    usage
  fi
  # prefere GPG if exists
  if [ -f $encFileBaseName.gpg ] ; then
    log "[INFO] decrypting $encFileBaseName.gpg for search ..."
    echo
    gpg $gpg_opt $encFileBaseName.gpg | egrep -i "$search_string"
  else
    echo
    log "[INFO] decrypting $encFileBaseName.enc for search ..."
    openssl $openssl_opt $encFileBaseName.enc | egrep -i "$search_string"
  fi
  exit
}

# ---------------- main entry --------------------

# commandline parse
while getopts $options opt; do
  case $opt in
    s)
      search_string=$OPTARG
      operation="search"
      ;;
    v)
      operation="view"
      ;;
    l)
      do_log=1
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

echo "" > $log_file
log "[INFO] `date`: $my_name starting ..."
do_check


if [ $operation = "view" ] ; then
  do_view
else
  do_search
fi
