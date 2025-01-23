#!/usr/bin/env bash
#
# ismalicious.sh --- Query ismalicious.com API and/or Project Honeypot API
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
# Version History:
#   Jan 14,  2025 --- Orginal version
#   Jan 17,  2025 --- Added additional check at ProjectHoneypot.org
#   Jan 23,  2025 --- Option to select which service to use.
#

# version format YY.MM.DD
version=25.01.23
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Query ismalicious.com API and/or Project Honeypot API"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:n:s:k:K:vh?"

supported_commands="reputation|vulnerabilities|geolocation|whois"
ismalicious_api_url_base="https://ismalicious.com/api/check"
projecthoneypart_dns_suffix="dnsbl.httpbl.org"

ismalicious_api_key_file="$HOME/.ismalicious.com-apikey.txt"
projecthoneypot_api_key_file="$HOME/.projecthoneypot.org-apikey.txt"
ismalicious_api_key=
projecthoneypot_api_key=

command_name="reputation"
name=""
service=0
http_output="/tmp/$(echo $my_name|cut -d. -f1).txt"


usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -c <command>  ---> command to run [Default: $command_name]. See supported commands below
  -n <name>     ---> Domain/IP name to check
  -s <service>  ---> Service# to use. Accepted values: 0=both 1=ismalicious 2=projecthoneypot [Default: $service]
  -k <apikey>   ---> ismalicious.com API key [Default: read from $ismalicious_api_key_file]
  -K <apikey>   ---> ProjectHoneypot access key [Default: read from $projecthoneypot_api_key_file]
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

Supported commands: $supported_commands  
example: $my_name -n 5.167.71.233
example: $my_name -c whois -n qouv.fr
 
EOF
  exit 0
}

# check using ismalicious API
check_ismalicious() {
  log.stat "Checking $command_name of $name using ismalicious API ..."
  http_status=$(curl -s -o $http_output -w "%{http_code}" -H "X-API-KEY: $ismalicious_api_key" ${ismalicious_api_url_base}/${command_name}?query=$name)
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
}

# decode the response
# See documentation at https://www.projecthoneypot.org/httpbl_api.php
#
# example decode of a return response: 127.1.55.1 
#   127 - always 127. If it is not 127, there was an error
#   1   - number of days last activity (0-255). Lower is most recent
#   55  - threat score (0-255). Higher is bad, 0 is no threat.
#   1   - type (0=searchengine; 1=suspicious, 2=harvester, 4=comment_spammer, rest are future use)
decode_projecthoneypot_response() {
  local resp=$1
  IFS='.' read -r -a resp_array <<< "$resp"
  if [ ${resp_array[0]} -ne 127 ] ; then
    log.error "\tERROR: response is not ${resp_array[2]} is not expected 127"
    return
  fi
  log.stat "\tMalicious:    YES [seen as recently as of last ${resp_array[1]} day(s)]." $red
  log.stat "\tThreat score: ${resp_array[2]}/255. [Note: score of 0 is clean]" $red
  log.stat "\tThreat type:  ${resp_array[3]} [note: 0=searchengine; 1=suspicious, 2=harvester, 4=comment_spammer]" $red
}

check_projecthoneypot() {
  # if name is not IP just ignore
  log.debug "Validating $name for IP address ..."
  validate_ip $name
  if [ $? -ne 0 ] ; then
    return
  fi

  log.stat "Checking $command_name of $name using ProjectHoneypot API ..." 
  # reverse IP to make DNS query with projecthonepot 
  rev_ip=$(reverse_ip $name)
  log.debug "Reversed IP: $rev_ip"

  dns_resp=`dig +short ${projecthoneypot_api_key}.$rev_ip.${projecthoneypart_dns_suffix}`
  log.debug "Project Honeypot response: $dns_resp"
  if [ "$dns_resp" != "" ] ; then
    decode_projecthoneypot_response $dns_resp
  else
    log.warn "\tEmpty response ProjectHoneypot API, likely no entry for this IP."
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

# read API and access keys for ismalicious.com and projecthoneypot.org
if [ -f $ismalicious_api_key_file ] ; then
  ismalicious_api_key=`cat $ismalicious_api_key_file`
fi
if [ -f $projecthoneypot_api_key_file ] ; then
  projecthoneypot_api_key=`cat $projecthoneypot_api_key_file`
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
    s)
      service="$OPTARG"
      if [[ ! "$service" =~ ^[0-2]$ ]] ; then
        log.error "Invalid service! It must be between 0-2, see usage below ..."
        usage
      fi
      ;;
    k)
      ismalicious_api_key="$OPTARG"
      ;;
    K)
      projecthoneypot_api_key="$OPTARG"
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

case $service in
  0)
    if [ -z "$ismalicious_api_key" ] && [ -z $projecthoneypot_api_key ] ; then
      log.error "Need API keys for service call, see usage below"
      usage
    fi
    # check ismalicious.com
    check_ismalicious
    # if the command is "reputation" check ProjectHoneyPot as well
    if [ "$command_name" == "reputation" ] ; then
      check_projecthoneypot
    fi
    ;;
  1)
    if [ -z "$ismalicious_api_key" ] ; then
      log.error "Need API keys for ismalicious.com, see usage below"
      usage
    fi
    # check ismalicious.com
    check_ismalicious
    ;;
  2)
    if [ -z "$projecthoneypot_api_key" ] ; then
      log.error "Need access keys for ProjectHoneypot, see usage below"
      usage
    fi
    # if the command is "reputation" check ProjectHoneyPot as well
    if [ "$command_name" == "reputation" ] ; then
      check_projecthoneypot
    fi
    ;;
  *)
    log.error "Invalid service: $service"
    usage
    ;;
esac

