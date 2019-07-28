#!/bin/sh
# 
# simple script to create dkim key for postfix
#
# Author:  Arul Selvan
# Version: Mar 16, 2014

# create the keys for the dkim setup
strength=1024

if [ $# -gt 0 ]; then 
  strength=$1
fi

#how to create PEM keys 
openssl genrsa -out private.key $strength
openssl rsa -in private.key -out public.key -pubout -outform PEM

# now copy it to right filename specified in postfix configs, in this
# example it is mail.*
cp private.key /etc/mail/mail.private.key
