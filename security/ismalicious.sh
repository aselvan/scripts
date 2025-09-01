#!/usr/bin/env bash
#
# ismalicious.sh --- Query ismalicious.com API
#
# Check if an IP/Domain's reputation, vulnerabilities, geolocaion or whois info using the
# ismalicious.com free API and/or projecthoneypot.org, and prints the JSON output.
# 
# Note: To use this script, create a free acount account on ismalicious.com and/or
#   projecthoneyport.org and place them in your home directory at filename shown below
#
#   $HOME/.ismalicious.com-apikey.txt      --- ismalicious.com API key
#   $HOME/.projecthoneypot.org-apikey.txt  --- projecthoneypot.org access key
#
# Author:  Arul Selvan
# Created: Jan 14, 2025
#
# See Also: ipabuse.sh isphishing.sh
#
# Version History:
#   Jan 14, 2025 --- Orginal version
#   Jan 17, 2025 --- Added additional check at ProjectHoneypot.org
#   Jan 23, 2025 --- Option to select which service to use.
#   Feb 5,  2025 --- Added ipqualityscore.com API
#   Sep 1,  2025 --- Moved ipquality, projecthoneypot to ipabuse.sh 
#

# version format YY.MM.DD
version=25.09.01
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Query ismalicious.com API"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:n:k:vh?"

supported_commands="reputation|vulnerabilities|geolocation|whois"
ismalicious_api_url_base="https://ismalicious.com/api/check"
ismalicious_api_key_file="$HOME/.ismalicious.com-apikey.txt"
ismalicious_api_key=
command_name="reputation"
name=""
http_output="/tmp/$(echo $my_name|cut -d. -f1).txt"


usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -c <command>  ---> command to run [Default: $command_name]. See supported commands below
  -n <name>     ---> Domain/IP name to check
  -k <apikey>   ---> ismalicious.com API key [Default: read from $ismalicious_api_key_file]
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

Supported commands: $supported_commands  
example(s): 
  $my_name -n 123.160.221.167
  $my_name -c whois -n qouv.fr
 
EOF
  exit 0
}

print_results() {
  case $command_name in
    reputation)
      log.stat "\tScore:      `cat $http_output|jq -r '.confidenceScore'`" 
      log.stat "\tMalicious:  `cat $http_output|jq -r '.reputation.malicious'`" 
      log.stat "\tSuspicious: `cat $http_output|jq -r '.reputation.suspicious'`" 
      log.stat "\t`cat $http_output|jq -r '.sources[] | "\(.category): \(.status)"'`" 
      log.stat "\tOutput:  $http_output"
    ;;
    vulnerabilities|geolocation|whois)
      cat $http_output|jq
    ;;
  esac
}

# check using ismalicious API
check_ismalicious() {
  log.stat "Checking $command_name of $name using ismalicious API ..."

  http_status=$(curl -s -o $http_output -w "%{http_code}" -H "X-API-KEY: $ismalicious_api_key" ${ismalicious_api_url_base}/${command_name}?query=$name)

  log.debug "HTTP status: $http_status"
  if [ "$http_status" -eq 200 ] ; then
    print_results
  elif [ "$http_status" -eq 429 ] ; then
    log.warn  "\tAPI returned: 'too many requests', retry again after few seconds."
  else
    log.error "\tAPI call failed! HTTP status = $http_status"
  fi
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

# require jq
check_installed jq

# read API and access keys for ismalicious.com and projecthoneypot.org
if [ -f $ismalicious_api_key_file ] ; then
  ismalicious_api_key=`cat $ismalicious_api_key_file`
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
      ismalicious_api_key="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check and validate valid command
if [[ "|$supported_commands|" != *"|$command_name|"* ]] ; then
  log.error "Unknown command: $command_name, see usage for valid commands"
  usage
fi

if [ -z "$name" ] ; then
  log.error "Missing name to query, see usage below"
  usage
fi

if [ -z "$ismalicious_api_key" ]  ; then
  log.error "Need API keys for ismalicious service call, see usage below"
  usage
fi

check_ismalicious

