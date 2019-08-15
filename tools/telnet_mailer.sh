#/bin/bash

#
# telnet_mailer.sh -- simple script to mail using telnet for testing or 
#                     mail servers don't have a MX record yet.
# 
# Author:  Arul Selvan
# Version: May 27, 2017
#

options_list="h:s:b:f:t:"
subject="telnet mailer"
body="test mail from telnet mailer script"
# change this
from="noreply@mydomain.com"
host="mysmtp.mydomain.com"
to=""
port=25

usage() {
  echo "Usage: $0 <-t <mailto>> [-h <mailhost> -s <subject> -b <body> -f <mailfrom>]"
  exit 1
}

while getopts "$options_list" opt; do 
  case $opt in 
    h)
      host=$OPTARG
      ;;
    s)
      subject=$OPTARG
      ;;
    b)
      body=$OPTARG
      ;;
    f)
      from=$OPTARG
      ;;
    t)
      to=$OPTARG
      ;;
    \?)
     echo "Invalid option: -$OPTARG"
     usage
     ;;
    :)
     echo "Option -$OPTARG requires and argument."
     usage
     ;;
   esac
done

# must have arg
if [ -z $to ]; then
  echo "Required arg -t is missing!"
  usage
fi

echo "Sending mail using '$host' server to '$to' from '$from' with mail content below  "
echo "Subject: $subject"
echo "Body: $body"

#
# Note: this can be done easily with netcat like "echo "xxxx"|nc $host $port 
# but the purpose of this script is to use telnet which is sure to be present 
# on any distro while netcat may or may not.
#
expect << EOF
  spawn telnet $host $port
  expect "Escape character is '^]'." 
  send "EHLO $host\n"
  expect "250" 
  send "MAIL FROM: <$from>\n"
  expect "250" 
  send "RCPT TO: <$to>\n"
  expect "250" 
  send "DATA\n"
  expect "354" 
  send "From: <$from>\n"
  send "To:   <$to>\n"
  send "Subject: $subject\n"
  send "$body\n"
  send ".\n"
  expect "250" 
  send "QUIT\n"
  expect "221" 
EOF
