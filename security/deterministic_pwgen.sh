#!/bin/bash

#
# deterministic_pwgen.sh --- simple wrapper over pwgen to produce deterministic password
#
# You can use this to create a strong password that is never stored anywhere like many 
# password utilities ex: OnePass,Keypass etc... All you have to remember 3 basic things
# and you can always reconstruct your password anytime.
# 
# 1. the master pass phrase (make this a large memorable sentance that is hard to guess)
# 2. the username or e-mail for the website you are creating password
# 3. the website name for which you are creating password.
#
# Note: Each password is specific to the username & website where these parameters are 
# used as salt to create unique strong password along with the passphrase.
#
# Author:  Arul Selvan
# Version: Sep 2, 2019
#

# special chars to avoid (some stupid websites don't allow certain special chars)
special_chars_to_avoid="[]\\/^}{<|>();?\""

# pwgen option
pwgen_opt="--remove-chars=$special_chars_to_avoid -N1 -cyn -1 16"
options="s:u:h"
website=""
user=""

# print usage
usage() {
  #clear
  name=`basename $0`
  cat <<EOF
  
  USAGE: $name -s <website> -u <username|email>
  
    <website> is the one you are generating password for
    <username|email> is used as additional info for creating salt
       
     example: $name -s yahoo.com -u foo@bar.com

EOF
  exit
}

# ----------- main entry -----------
while getopts $options opt; do
  case $opt in
    s)
      website=$OPTARG
      ;;
    u)
      user=$OPTARG
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

if [[ -z $website || -z $user ]]; then
  echo "[ERROR] missing args"
  usage
fi

type pwgen >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[ERROR] required command 'pwgen' is not found or in the path, install it and try again..."
  exit
fi

# echo the prompt to stderr so the output (i.e. generated password) can be captured instead of 
# printing on shell. ex: in MacOS you can do name -s yahoo.com -u foo@bar.com|pbcopy to 
# directly read into the past buffer.
>&2 echo "Enter your passphrase: " 

read -s pass_phrase

passwd=`pwgen $pwgen_opt -H <(printf $pass_phrase)#$user:$website`

echo $passwd
