#!/bin/sh
#
# tesla_token.sh --- wrapper script to get/refresh a bearer token for your car to 
#    to use with other API calls. 
#
##################################################################################
# OBSOLETE:
# --------
# This script is obsolete. Use one of the methods referenced in the link below to 
# obtain your bearer token. Tesla recently changed the way i.e. made it more secure 
# to get the bearer token which is a good thing.
#
# Manual way: https://tesla-api.timdorr.com/api-basics/authentication
# Automated way: https://github.com/bntan/tesla-tokens
#
##################################################################################
#
#
# DISCLAIMER:
# -----------
#
# This scripts use Tesla's unofficial APIs i.e. https://owner-api.teslamotors.com/oauth/token
# and comes without warranty of any kind what so ever. You are free to use it at your 
# own risk. I assume no liability for the accuracy, correctness, completeness, or 
# usefulness of any information provided by this scripts nor for any sort of damages 
# using these scripts may cause.
#
# Author:  Arul Selvan
# Version: May 31, 2020
#
# API reference: https://tesla-api.timdorr.com/
# Client ID & Secret: https://pastebin.com/pS7Z6yyP
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
tesla_api_ep=https://owner-api.teslamotors.com/oauth/token
client_id="81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
client_secret="c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
refresh_token_file="$HOME/.mytesla.refresh.token"
refresh_token=""

usage() {
  echo "Usage: $my_name <create|refresh>"
  echo "  $0 create <email> <password>"
  echo "  $0 refresh <refresh_token>"     
  exit 0
}

log() {
  message_type=$1
  message=$2
  echo "$message_type $message" | tee -a $log_file
}

read_token_from_file() {
  if [ -f $refresh_token_file ] ; then
    refresh_token=`cat $refresh_token_file`
  else
    log "[ERROR]" "$refresh_token_file file missing!"
    exit
  fi
}

# create bearer token
create() {
  tesla_account_email=$1
  tesla_account_password=$2

  if [[ -z $tesla_account_email || -z $tesla_account_password ]] ; then
    echo "[ERROR] required args (email or password) missing!"
    usage
  fi

  log "[INFO]" "creating token for tesla account: $tesla_account_email ...\n"
  curl -X POST \
    -H "Cache-Control: no-cache" \
    -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
    -F "grant_type=password" \
    -F "client_id=${client_id}" \
    -F "client_secret=${client_secret}" \
    -F "email=${tesla_account_email}" \
    -F "password=${tesla_account_password}" -w "\n\n" \
    $tesla_api_ep
}

# refresh bearer token
refresh() {
  refresh_token=$1
  if [[ -z $refresh_token ]] ; then
    log "[WARN]" "required arg 'refresh_token' missing, attempting to read from $refresh_token_file!"
    read_token_from_file
  fi
  log "[INFO]" "refreshing token: $refresh_token ..."
  curl -X POST \
    -H "Cache-Control: no-cache" \
    -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
    -F "grant_type=refresh_token" \
    -F "client_id=${client_id}" \
    -F "client_secret=${client_secret}" \
    -F "refresh_token=${refresh_token}" -w "\n\n" \
    $tesla_api_ep
}

# ----------  main --------------
echo "[INFO] `date`: Starting $my_name ..." > $log_file
cat << EOF
##################################################################################
# OBSOLETE:
# --------
# This script is obsolete. Use one of the methods referenced in the link below to 
# obtain your bearer token. Tesla recently changed the way i.e. made it more secure 
# to get the bearer token which is a good thing.
#
# Manual way: https://tesla-api.timdorr.com/api-basics/authentication
# Automated way: https://github.com/bntan/tesla-tokens
#
##################################################################################
EOF
exit

case $1 in
  create|refresh) "$@"
  ;;
  *) usage
  ;;
esac

