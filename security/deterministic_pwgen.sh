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
# Pre-req:
#   Requires the pwgen utility installed. Install for your OS as shown below.
#   macOS: brew install pwgen
#   Linux: apt-get install pwgen
#
# OS: 
#   MacOS or any Linux distro
#
# Author:  Arul Selvan
# Version: Sep 2, 2019
#

# special chars to avoid.
# Note: there are some dumb/stupid websites don't allow certain special chars
special_chars_to_avoid="&*~\'\`,[]\\/^}{<|>();?\""

# pwgen option
pwgen_opt="--remove-chars=$special_chars_to_avoid -N1 -cny -1 12"
options="w:u:hp"
website=""
user=""
print_console=0
os_name=`uname -s`
my_name=`basename $0`


# print usage
usage() {
  #clear
  cat <<EOF
Usage: $my_name -w <website> -u <username|email> [-p]
  -w <website>        ---> The website the password is generated for (just use domain name not FQDN)
  -u <username|email> ---> The username used for the website specified above.
  -p                  ---> will print the password to console.
       
  example: $my_name -s yahoo.com -u foo@bar.com

EOF
  exit
}

# ----------- main entry -----------
while getopts $options opt; do
  case $opt in
    w)
      website=$OPTARG
      ;;
    u)
      user=$OPTARG
      ;;
    p)
      print_console=1
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
  echo "[ERROR] missing required args i.e. username or website!"
  usage
fi

type pwgen >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[ERROR] required command 'pwgen' is not found or in the path, install it and try again..."
  exit
fi

>&2 echo "Enter your passphrase: " 
read -s pass_phrase
passwd=`pwgen $pwgen_opt -H <(printf "$pass_phrase")#$user:$website`

# copy to pastebuffer for easy access
# pastebuffer depending on OS
if [ $os_name = "Darwin" ]; then
  echo -n $passwd | pbcopy
else
  echo -n $passwd | xsel --clipboard --input
fi
echo "[INFO] generated password is now copied into your paste buffer for easy access."

# print to console if requested
if [ $print_console -eq 1 ] ; then
  echo "[INFO] your generated password is: $passwd"
fi

