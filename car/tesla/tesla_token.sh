#!/bin/sh
#
# tesla_token.sh --- wrapper script to get a bearer token for your car to 
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
tesla_account_email="your_tesla_email"
tesla_account_password="your_tesla_password"

curl -X POST -H "Cache-Control: no-cache" \
  -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
  -F "grant_type=password" -F "client_id=${client_id}" -F "client_secret=${client_secret}" \
  -F "email=${tesla_account_email}" -w "\n" \
  -F "password=${tesla_account_password}" $tesla_api_ep

