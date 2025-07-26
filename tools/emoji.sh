#!/usr/bin/env bash
################################################################################
# emoji.sh --- Convert emoji <-> description using emoji-api.com API
#
# Lookup emoji for a description or lookup description for an emoji
#
#   $HOME/.emoji-api.com-apikey.txt      --- emoji.com API key
#
# Author:  Arul Selvan
# Created: Jul 25, 2025
################################################################################
#
# Version History:
#   Jul 25,  2025 --- Original version
################################################################################

# version format YY.MM.DD
version=25.07.25
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Lookup emoji for a description or lookup description for an emoji"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:d:vh?"

emoji_api_url_base="https://emoji-api.com/emojis?search="
emoji_api_key_file="$HOME/.emoji.com-apikey.txt"
emoji_api_key=
http_output="/tmp/$(echo $my_name|cut -d. -f1).txt"

emoji_char=""
emoji_desc=""

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -i <emoji> ---> emoji char to lookup for description
  -d <desc>  ---> print emoji matching description
  -k <key>   ---> emoji-api.com key [Default: $emoji_api_key_file]
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

examples: 
  $my_name -i 😊            # prints the description matching emoji
  $my_name -d "pink-heart"  # prints the emoji matching description (no space)
 
EOF
  exit 0
}

# encode emoji unicode to encoded string like #0x#0x#0x to pass to API
emoji2hex_encode() {
  local i="$1"
  printf '%s' "$i" | xxd -p -c1 | while read -r byte; do
    printf '%%%s' "$byte"
  done
  echo
}


# lookup description for an emoji
do_emoji_lookup() {
  local s=""
  
  if [ -z "$emoji_api_key" ] ; then
    log.error "emoji-api.com API key missing, see usage and provide valid key"
    usage
  fi
  log.stat "Query using emoji-api.com API ..."
  

  # if emoji provided, convert to hex representation
  if [ ! -z "$emoji_char" ] ; then
    s=`emoji2hex_encode $emoji_char`
    log.stat "Lookup description for '${emoji_char}'"
  else
    log.stat "Lookup emoji value for '${emoji_desc}'"
    s=$emoji_desc
  fi

  local uri="${emoji_api_url_base}${s}&access_key=${emoji_api_key}"
  log.debug "URL: $uri"
  http_status=$(curl -s -o $http_output -w "%{http_code}" "${uri}")
  log.debug "HTTP status: $http_status"
  
  if [ "$http_status" -eq 200 ] ; then
    check_installed jq noexit
    if [ $? -eq 0 ] ; then
      cat $http_output | jq
    else
      cat $http_output
    fi
  elif [ "$http_status" -eq 429 ] ; then
    log.warn  "\tAPI returned: 'too many requests', retry again after few seconds."
  else
    log.error "\tAPI call failed! HTTP status = $http_status"
  fi
  echo
  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

# read API and access keys for emoji-api.com 
if [ -f $emoji_api_key_file ] ; then
  emoji_api_key=`cat $emoji_api_key_file`
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    i)
      emoji_char="$OPTARG"
      do_emoji_lookup
      ;;
    d)
      emoji_desc="$OPTARG"
      do_emoji_lookup
      ;;
    k)
      emoji_api_key="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

usage

