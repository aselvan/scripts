#!/usr/bin/env bash
#
# mypass.sh -- Simple script to add/search passwords using encrypted file
#
# Author:  Arul Selvan
# Version; Jul 7, 2017
# 
# requirement: openssl 
# Platform support: MacOS, Linux or any OS that has bash and openssl (tested on macOS)
#
# Version History
#   Jul 7, 2017  --- original version
#   Jan 19, 2024 --- modified to use logger and function includes
#
# TODO: need ability to modify

# version format YY.MM.DD
version=24.01.19
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Simple encrypted password manager"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:aw:u:p:lhv?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

enc_file_path="$HOME/encrypted"
enc_file="$enc_file_path/mypass.enc"
website=""
user=""
password=""
op=""
pbc="xsel --clipboard --input"
openssl_opt="-pbkdf2 -md md5 -aes-256-cbc -a -salt"


usage() {
	cat <<EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <website>  ---> Name of website to search or add in case of -a
  -a <website>  ---> Add new website credentials (requires additional args below)
  -u <username> ---> The username for the website
  -p <password> ---> The password for the website
  -l            ---> List all entries (password will not be shown)
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

  Search example:
    example: $my_name -s yahoo.com

  Add example:
    example: $my_name -a -w yahoo.com -u username -p pasword123
EOF
  exit
}

add_entry() {
	echo -n Enter passphrase:
	read -s pass_phrase
  echo

	log.stat "ADD: $website, $user & password to encrypted file"
  # decrypt the existing file and append our current line and encrypt it back
  if [ -f $enc_file ] ; then
    # need to backup first
    cp $enc_file $enc_file.backup
		openssl enc -d $openssl_opt -in $enc_file -k $pass_phrase 2>/dev/null > $enc_file.tmp
    if [ $? -ne 0 ] ; then
      log.error "Error decrypting: perhaps you entered invalid passphrase? Try again." 
      exit
    fi
		echo "$website,$user,$password" >> $enc_file.tmp
	else
		echo "$website,$user,$password" > $enc_file.tmp
	fi

	# now encrypt the file and securely remove the tmp file.
	openssl enc -e $openssl_opt -in $enc_file.tmp -k $pass_phrase -out $enc_file
	$srm $enc_file.tmp
}

list_all() {
	echo -n Enter passphrase:
	read -s pass_phrase
	echo
	log.stat "List all entries (password will not be listed)"
	openssl enc -d $openssl_opt -in $enc_file -k $pass_phrase 2>/dev/null  >/tmp/.${my_name}_tmp 
  if [ $? -ne 0 ] ; then
    log.error "Error decrypting: perhaps you entered invalid passphrase? Try again."
    exit 1
  fi
  while IFS= read -r line ; do
    IFS=, read -r ws un pw <<< $line
    log.stat "Website: $ws, Username: $un" $green
  done < /tmp/.${my_name}_tmp
  $srm /tmp/.${my_name}_tmp
}

search_entry() {
	echo -n Enter passphrase:
	read -s pass_phrase
	echo
	log.stat "Searching login for: $website"
	openssl enc -d $openssl_opt -in $enc_file -k $pass_phrase 2>/dev/null | grep -i $website >/tmp/.${my_name}_tmp 
  # need to save these first, otherwise they are gone.
  status_list=( ${PIPESTATUS[*]} )
  if [ ${status_list[0]} -ne 0 ] ; then
    log.error "Error decrypting: perhaps you entered invalid passphrase? Try again." 
    echo
    exit 1
  elif [ ${status_list[1]} -ne 0 ] ; then
    log.warn "Search failed: '$website' is not found!. Did you add it before?"
    echo
    exit 2
  fi
  # If there are multiple entries, first one wins [ideally there should not be multiple entries of same website]
  while IFS= read -r line ; do
    IFS=, read -r ws un pw <<< $line
    if [ "$website" = "$ws" ] ; then
      echo -n $pw | $pbc
      log.stat "  username: $un (password is copied to paste buffer for convenience)" $green
      break
    fi
  done < /tmp/.${my_name}_tmp
  $srm /tmp/.${my_name}_tmp
}

# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# alias secure remove
if [ $os_name = "Darwin" ]; then
  srm="rm -P"
  pbc="pbcopy"
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
    l)
      op="list"
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
    ?|h|*)
      usage
      ;;
    esac
done

if [ -z $op ]; then
	usage
fi

if [ $op = "add" ]; then
	if [[ -z $user ||  -z $password || -z $website ]] ; then
    log.error "Missing required args! See usage below"
		usage
	fi
	add_entry
elif [ $op = "search" ]; then
	if [ -z $website ] ; then
    log.error "Missing required i.e. -s <website>. See usage below"
		usage
	fi
	search_entry
elif [ $op = "list" ] ; then
  list_all
fi
