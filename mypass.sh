#!/bin/bash
#
# mypass.sh -- simple script to add/search passwords from encrypted file
#
# Author:  Arul Selvan
# Version; Jul 7, 2017
# 
# requirement: openssl 
# Platform support: MacOS, Linux or any OS that has bash and openssl (tested on macOS)
#
enc_file_path="$HOME/encrypted"
enc_file="$enc_file_path/mypass.enc"
website=""
user=""
password=""
op=""

options="s:aw:u:p:"

usage() {
  clear
  name=`basename $0`
	cat <<EOF
  
  Usage: $name
  ----------------
  
  Search:
    $name -s <website> 
     
    where <website> is the one to search for user/password.
    example: $name -s yahoo.com

  Add:
    $name -a -w <website> -u <user> -p <password>
    
    where <user> and <password> and <website> will be added to encrypted file
    example: $name -a -w yahoo.com -u username -p secret

EOF
  exit
}

add_entry() {
	echo -n Enter passphrase:
	read -s pass_phrase
	echo

	echo "ADD: $website, $user & password to encrypted file"
  # decrypt the existing file and append our current line and encrypt it back
  if [ -f $enc_file ] ; then
    # need to backup first
    cp $enc_file $enc_file.backup
		openssl enc -d -aes-256-cbc -a -in $enc_file -k $pass_phrase 2>/dev/null > $enc_file.tmp
    if [ $? -ne 0 ] ; then
      echo "ERROR decrypting: perhaps you entered invalid passphrase? Try again." 
      exit
    fi
		echo "website: $website, user/passwd: $user/$password" >> $enc_file.tmp
	else
		echo "website: $website, user/passwd: $user/$password" > $enc_file.tmp
	fi

	# now encrypt the file and securely remove the tmp file.
	openssl enc -aes-256-cbc -a -salt -in $enc_file.tmp -k $pass_phrase -out $enc_file
	$srm $enc_file.tmp
}

search_entry() {
	echo -n Enter passphrase:
	read -s pass_phrase
	echo
	echo "Searching login for: $website"
	openssl enc -d -aes-256-cbc -a -in $enc_file -k $pass_phrase 2>/dev/null | grep -i $website
  # need to save these first, otherwise they are gone.
  status_list=( ${PIPESTATUS[*]} )

  if [ ${status_list[0]} -ne 0 ] ; then
    echo "ERROR decrypting: perhaps you entered invalid passphrase? Try again." 
    echo ""
    exit
  elif [ ${status_list[1]} -ne 0 ] ; then
    echo "SEARCH Failed: '$website' is not found!. Did you add it before?"
    echo ""
  fi
}

# ----------- main entry -----------
# alias secure remove
if [ `uname -s` = "Darwin" ]; then
  srm="rm -P"
elif [ ! -f /usr/bin/srm ]; then
  srm="rm"
else
  srm="srm"
fi

# ensure the path exists
if [ ! -d $enc_file_path ] ; then
  mkdir -p $enc_file_path
fi

while getopts $options opt; do 
  case $opt in
    s)
      op="search"
      website=$OPTARG
      ;;
    a)
      op="add"
      ;;
    w)
      website=$OPTARG
      ;;
    u)
      user=$OPTARG
      ;;
    p)
      password=$OPTARG
      ;;

    ?) 
			usage 
			;;
    esac
done

if [ -z $op ]; then
	usage
fi

if [ $op = "add" ]; then
	if [[ -z $user ||  -z $password || -z $website ]] ; then
		usage
	fi
	add_entry
elif [ $op = "search" ]; then
	if [ -z $website ] ; then
		usage
	fi
	search_entry
fi

