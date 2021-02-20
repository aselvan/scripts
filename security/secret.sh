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
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="s:vqh"

encFileBaseName="kanakku.txt"
search_string=""
gpg_opt="-qd"
openssl_opt="enc -d -aes-256-cbc -a -in"
vi_bin="/usr/bin/view"

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -s <string> ==> decrypt and regex search for 'string' in the content
  -v          ==> decrypt and open the file w/ vi (view)

  example: $my_name -s foobar

EOF
  exit
}

# validate path, file etc.
do_check() {
  # directory where the encrypted files are stored
  echo "[INFO] checking KEYS_HOME in environment ..." | tee -a $log_file
  if [ -z $KEYS_HOME ] ; then
    KEYS_HOME="$HOME/data/personal/keys"
    echo "[INFO] KEYS_HOME not found, defaulting to $KEYS_HOME" |tee -a $log_file
  else
    echo "[INFO] KEYS_HOME is $KEYS_HOME" |tee -a $log_file  
  fi

  if [ ! -d $KEYS_HOME ] ; then
    echo "[ERROR] KEYS_HOME=$KEYS_HOME does not exists!" | tee -a $log_file
    exit 1
  fi
  cd $KEYS_HOME || exit 2
  if [[ ! -f $encFileBaseName.enc || ! -f $encFileBaseName.gpg ]] ; then
    echo "[ERROR] missing encrypted file(s) [$encFileBaseName.enc or $encFileBaseName.gpg]" | tee -a $log_file
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
    echo "[INFO] decrypting $encFileBaseName.gpg for view ..." | tee -a $log_file 
    gpg $gpg_opt $encFileBaseName.gpg | $vi_bin -
  else
    echo "[INFO] decrypting $encFileBaseName.enc for view ..." | tee -a $log_file 
    openssl $openssl_opt | $vi_bin -
  fi
  exit
}

do_search() {
  if [ -z $search_string ] ; then
    echo "[ERROR] search string is missing!" | tee -a $log_file
    usage
  fi
  # prefere GPG if exists
  if [ -f $encFileBaseName.gpg ] ; then
    echo "[INFO] decrypting $encFileBaseName.gpg for search ..." | tee -a $log_file
    echo
    gpg $gpg_opt $encFileBaseName.gpg | egrep -i "$search_string"
  else
    echo
    echo "[INFO] decrypting $encFileBaseName.enc for search ..." | tee -a $log_file 
    openssl $openssl_opt $encFileBaseName.enc | egrep -i "$search_string"
  fi
  exit
}

# ---------------- main entry --------------------
echo "[INFO] `date`: $my_name starting ..." | tee $log_file
do_check

# commandline parse
while getopts $options opt; do
  case $opt in
    s)
      search_string=$OPTARG
      do_search
      ;;
    v)
      do_view
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

# if no args show usage
usage
