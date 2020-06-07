#!/bin/sh
#
# tesla_token.sh --- wrapper script to get/refresh a bearer token for your car to 
#    to use with other API calls. 
#
# Author:  Arul Selvan
# Version: May 31, 2020
#
# API reference: https://tesla-api.timdorr.com/
# Client ID & Secret: https://pastebin.com/pS7Z6yyP
#

tesla_api_ep=https://owner-api.teslamotors.com/oauth/token
client_id="81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
client_secret="c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"

usage() {
  echo "Usage: $0 <create|refresh>"
  echo "  $0 create <email> <password>"
  echo "  $0 refresh <refresh_token>"     
  exit 0
}

# create bearer token
create() {
  tesla_account_email=$1
  tesla_account_password=$2

  if [[ -z $tesla_account_email || -z $tesla_account_password ]] ; then
    echo "[ERROR] required args (email or password) missing!"
    usage
  fi

  echo "[INFO] creating token for tesla account: $tesla_account_email ...\n"
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
    echo "[ERROR] required arg (refresh_token) missing!"
    usage
  fi
  echo "[INFO] refreshing token: $refresh_token ...\n"
  curl -X POST \
    -H "Cache-Control: no-cache" \
    -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
    -F "grant_type=refresh_token" \
    -F "client_id=${client_id}" \
    -F "client_secret=${client_secret}" \
    -F "refresh_token=${refresh_token}" -w "\n\n" \
    $tesla_api_ep
}

case $1 in
  create|refresh) "$@"
  ;;
  *) usage
  ;;
esac

