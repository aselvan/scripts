#!/usr/bin/env bash
################################################################################
# dns_rebind_check.sh --- check if a website operator is a DNS rebind attacker
#
#
# Author:  Arul Selvan
# Created: Jul 30, 2024
################################################################################
# Version History:
#   Jul 30, 2025 --- Original version
################################################################################

# version format YY.MM.DD
version=25.07.30
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="check if a website operator is a DNS rebind attacker"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="d:n:t:vh?"

domain=""
ttl_threshold=300
dns_server=`dig selvans.net | grep 'SERVER' | awk '{print $3}' | cut -d'#' -f1`

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -d <domain> ---> domain name to check if they do DNS rebind attack
  -n <ns>     ---> use the provided NS [Default: $dns_server]
  -t <ttl>    ---> TTL threashold to check [Default: $ttl_threshold]
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example(s): 
  $my_name -d yahoo.com
  
EOF
  exit 0
}

check_rebind() {
  local rc=0

  # get auth TTL
  auth_ns=$(dig +short NS $domain @$dns_server | head -n1)
  if [ -z "$auth_ns" ] ; then
    log.error "Unable to determine authoritative DNS for $domain, exiting"
    exit 1
  fi
  auth_ns=${auth_ns%.}  # Strip trailing dot if present
  auth_ttl=$(dig +nocmd +noall +answer $domain @$auth_ns | awk '{print $2}' | head -n1)

  # Query default resolver to get cache TTL & IP
  cached_ttl=$(dig +nocmd $domain +noall +answer @$dns_server | awk '{print $2}' | head -n1)
  ip=$(dig +short $domain @$dns_server | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  is_ip_private $ip
  local is_private=$?

  # debug logs
  log.debug "\tIP:          $ip"
  log.debug "\tIP Private?: $is_private"
  log.debug "\tAuth NS:     $auth_ns"
  log.debug "\tUsed NS:     $dns_server"
  log.debug "\tAuth TTL:    $auth_ttl"
  log.debug "\tCached TTL:  $cached_ttl"

  # check if we got any invalid TTLs
  if [ -z "$auth_ttl" ] ; then
    log.error "Unable to read auth TTL!, exiting"
    exit 2
  fi

  # if authoritative TTL is way low, clear indication of DNS rebind attacker
  if [[ $auth_ttl -le $ttl_threshold && is_private -eq 1  ]] ; then
    log.error "CRITICAL: Low TTL from authoritative server and returned IP is private!"
    log.error "$domain is a definitly source for DNS rebind attack! Stay away."
  elif [ $auth_ttl -le $ttl_threshold ] ; then
    log.error "CAUTION: Low TTL from authoritative server!"
    log.error "$domain is a definitly source for DNS rebind attack! Stay away."
  else
    log.stat "$domain is good, not a DNS rebind attacker" $green
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    d)
      domain="$OPTARG"
      ;;
    n)
      dns_server="$OPTARG"
      ;;
    t)
      ttl_threshold="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$domain" ] ; then
  log.error "Missing domain argument, see usage"
  usage
fi

check_rebind
