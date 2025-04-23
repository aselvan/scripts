#!/usr/bin/env bash
#
# isphishing.sh --- Query phishstats.info API to see if IP/URL considered phishing
#
#
# Author:  Arul Selvan
# Created: Apr 22, 2025
#
# Version History:
#   Apr 22,  2025 --- Orginal version
#

# version format YY.MM.DD
version=25.04.22
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Query phishstats.info API to see if IP/URL considered phishing site"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="u:i:n:s:vh?"

# we only check if score is > than 4
score_level=4
num_records=1
ip=""
url=""
uri=""
phishstats_site="phishstats.info"
phishstats_url_base="https://${phishstats_site}:2096/api/phishing?_where="
http_output="/tmp/$(echo $my_name|cut -d. -f1).txt"


usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -u <url>   ---> URL to check. Note: partial is ok
  -i <ip>    ---> IP to check. Note: IP must be exact
  -n <rows>  ---> Total number of rows to fetch [Default: $num_records]
  -s <range> ---> Check score (0-2 likely 2-4 suspicious 4-6 phishing 6-10 phishing) [Default: $score_level]
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example(s)0: 
  $my_name -i 5.167.71.233
  $my_name -u "pages.dev"
EOF
  exit 0
}

slow_warning() {
  log.stat "Querying $phishstats_site ..."
  log.stat "$phishstats_site site is extreemly slow, response can take very long time. Please wait ..." $black
}

make_api_call() {
  http_status=$(curl -s -o $http_output -w "%{http_code}" "$uri")
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

ip_check() {
  validate_ip $ip
  if [ $? -ne 0 ]; then
    log.error "The IP provided i.e. $ip is invalid!"
  fi
  slow_warning
  uri="${phishstats_url_base}(score,gt,$score_level)~and(ip,eq,$ip)&_size=$num_records"
  make_api_call
}

url_check() {
  slow_warning
  uri="${phishstats_url_base}(score,gt,$score_level)~and(url,like,~${url}~)&_size=$num_records"
  make_api_call
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    i)
      ip="$OPTARG"
      ;;
    u)
      url="$OPTARG"
      ;;
    n)
      score_level="$OPTARG"
      ;;
    s)
      num_records="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$ip" ] && [ -z $url ] ; then
  log.error "Missing arguments. Need IP or URL, see usage below"
  usage
elif [ ! -z "$ip" ] ; then
  ip_check
else
  url_check
fi
