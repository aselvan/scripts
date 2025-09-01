#!/usr/bin/env bash
#
# ipabuse.sh --- Query using abuseipdb.com API to check if IP is abusive
#
# 
# Note: To use this script, create a free acount account on abuseipdb.com 
#
#   $HOME/.abuseipdb.com-apikey.txt      --- abuseipdb.com API key
#
# Author:  Arul Selvan
# Created: Sep 1, 2025
#
# Version History:
#   Sep 1,   2025 --- Orginal version
#   Sep 1,   2025 --- Moved projecthoneypot, ipquality from ismalicious.sh
#
# See Also:
#   ismalicious.sh isphishing.sh
#

# version format YY.MM.DD
version=25.09.01
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Query using abuseipdb.com API to check if IP is abusive"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:A:P:I:vh?"

abuseipdb_api_url_base="https://api.abuseipdb.com/api/v2/check"
ipqualityscore_api_url_base="https://www.ipqualityscore.com/api/json/url"
projecthoneypart_dns_suffix="dnsbl.httpbl.org"

abuseipdb_api_key_file="$HOME/.abuseipdb.com-apikey.txt"
projecthoneypot_api_key_file="$HOME/.projecthoneypot.org-apikey.txt"
ipqualityscore_api_key_file="$HOME/.ipqualityscore-apikey.txt"

abuseipdb_api_key=
projecthoneypot_api_key=""
ipqualityscore_api_key=""

ip=""
http_output_abuseipdb="/tmp/$(echo $my_name|cut -d. -f1)_abuseipdb.txt"
http_output_ipquality="/tmp/$(echo $my_name|cut -d. -f1)_ipquality.txt"
days=180


usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -i <ip>       ---> IP to check
  -A <apikey>   ---> ipabuse.com API key [Default: read from $abuseipdb_api_key_file]
  -P <apikey>   ---> ProjectHoneypot access key [Default: read from $projecthoneypot_api_key_file]
  -I <apikey>   ---> IPqualityscore API key [Default: read from $ipqualityscore_api_key_file]
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help

example(s): 
  $my_name -i 123.160.221.167
 
EOF
  exit 0
}

# check using abuseipdb API
check_abuseipdb() {
  log.stat "Checking $ip using abuseipdb.com API ..."

  http_status=$(curl -s -G -o $http_output_abuseipdb -w "%{http_code}" --data-urlencode "ipAddress=$ip" -d maxAgeInDays=$days -H "Key: $abuseipdb_api_key" -H "Accept: application/json" ${abuseipdb_api_url_base})
  log.debug "HTTP status: $http_status"
  if [ "$http_status" -eq 200 ] ; then
    abuse_score=$(cat $http_output_abuseipdb | jq '.data.abuseConfidenceScore')
    total_reports=$(cat $http_output_abuseipdb | jq '.data.totalReports')
    log.stat "\tReports:     $total_reports"
    log.stat "\tAbuse Score: $abuse_score"
    log.stat "\tOutput:      $http_output_abuseipdb"
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
  log.stat "Checking $ip using ProjectHoneypot API ..." 

  # validate IP
  log.debug "Validating $name for IP address ..."
  validate_ip $ip
  if [ $? -ne 0 ] ; then
    log.error "$ip is not a valid IP, skipping ..."
    return
  fi

  # reverse IP to make DNS query with projecthonepot 
  rev_ip=$(reverse_ip $ip)
  log.debug "Reversed IP: $rev_ip"

  dns_resp=`dig +short ${projecthoneypot_api_key}.$rev_ip.${projecthoneypart_dns_suffix}`
  log.debug "Project Honeypot response: $dns_resp"
  if [ "$dns_resp" != "" ] ; then
    decode_projecthoneypot_response $dns_resp
  else
    log.warn "\tEmpty response ProjectHoneypot API, likely no entry for this IP."
  fi
}

check_ipqualityscore() {
  log.stat "Checking $ip using ipqualityscore.com API ..."

  http_status=$(curl -s -o $http_output_ipquality -w "%{http_code}" ${ipqualityscore_api_url_base}/${ipqualityscore_api_key}/${ip})
  log.debug "HTTP status: $http_status"
  if [ "$http_status" -eq 200 ] ; then
    log.stat "\tSuspicious: `cat $http_output_ipquality | jq '.suspicious'`"
    log.stat "\tRiskScore:  `cat $http_output_ipquality | jq '.risk_score'`"
    log.stat "\tPhishing:   `cat $http_output_ipquality | jq '.phishing'`"
    log.stat "\tSpamming:   `cat $http_output_ipquality | jq '.spamming'`"
    log.stat "\tMalware:    `cat $http_output_ipquality | jq '.malware'`"
    log.stat "\tOutput:      $http_output_ipquality"    
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

# read API and access keys for ipabuse.com and projecthoneypot.org
if [ -f $abuseipdb_api_key_file ] ; then
  abuseipdb_api_key=`cat $abuseipdb_api_key_file`
fi
if [ -f $projecthoneypot_api_key_file ] ; then
  projecthoneypot_api_key=`cat $projecthoneypot_api_key_file`
fi
if [ -f $ipqualityscore_api_key_file ] ; then
  ipqualityscore_api_key=`cat $ipqualityscore_api_key_file`
fi

# parse commandline options
while getopts $options opt ; do
  case $opt in
    i)
      ip="$OPTARG"
      ;;
    A)
      abuseipdb_api_key="$OPTARG"
      ;;
    P)
      projecthoneypot_api_key="$OPTARG"
      ;;
    I)
      ipqualityscore_api_key="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$ip" ] ; then
  log.error "Missing IP to query, see usage below"
  usage
fi

# call and check all services if keys are available.
if [ ! -z "$abuseipdb_api_key" ] ; then
  check_abuseipdb
fi

if [ ! -z "$projecthoneypot_api_key" ] ; then
  check_projecthoneypot
fi

if [ ! -z "$ipqualityscore_api_key" ] ; then
  check_ipqualityscore
fi

