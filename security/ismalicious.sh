#!/usr/bin/env bash
#
# ismalicious.sh --- wrapper over ismalicious.com API 
#
# Check if an IP/Domain's reputation, vulnerabilities, geolocaion or whois info using the
# ismalicious.com free API and prints the JSON output
# 
# Note: To use this script, create a free acount account and get API key and place it
# in your $HOME/.ismalicious.com-apikey.txt  or pass it via commandline
#
# Author:  Arul Selvan
# Created: Jan 14, 2025
#
# Version History:
#   Jan 14,  2025 --- Orginal version
#

# version format YY.MM.DD
version=25.01.14
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Query using ismalicious.com API"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:n:k:vh?"

api_url_base="https://ismalicious.com/api/check"
api_key_file="$HOME/.ismalicious.com-apikey.txt"
supported_commands="reputation|vulnerabilities|geolocation|whois"
command_name=""
api_key=""
name=""


usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -c <command>  ---> command to run [see supported commands below].
  -n <name>     ---> Domain/IP name to check
  -k <apikey>   ---> ismalicious.com API key [Default: read from $api_key_file]
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

Supported commands: $supported_commands  
example: $my_name -c reputation -n 5.167.71.233
example: $my_name -c whois -n qouv.fr 
 
EOF
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
check_installed "jq"

# read default api key
if [ -f $api_key_file ] ; then
  api_key=`cat $api_key_file`
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    n)
      name="$OPTARG"
      ;;
    k)
      api_key="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for any commands and validate valid commands
if [ -z "$command_name" ] ; then
  log.error "Missing command, see usage below"
  usage
else
  if [[ "|$supported_commands|" != *"|$command_name|"* ]] ; then
    log.error "Unknown command: $command_name, see usage for valid commands"
    usage
  fi
fi

if [ -z "$name" ] ; then
  log.error "Missing name to query, see usage below"
  usage
fi

if [ -z "$api_key" ] ; then
  log.error "Missing API key, see usage below"
  usage
fi

log.stat "$my_title for $command_name of $name ..."
curl -s -H "X-API-KEY: $api_key" ${api_url_base}/${command_name}?query=$name | jq
