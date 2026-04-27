#!/usr/bin/env bash
################################################################################
# isbreached.sh --- check presense of email and/or password data breaches.
#
#  This is a wrapper script over xposedornot.com free API to check presense of
#  your email and/or password expossure on any of the major data breaches todate
#
# Author:  Arul Selvan
# Created: Apr 27, 2026
#
# Preq: sha3sum & jq (install with 'brew install sha3sum jq')
#
# See Also: ismalicious.sh ipabuse.sh dns_rebind_check.sh ... etc
################################################################################
#
# Version History: (original & last 3)
#   Apr 27, 2024 --- Original version
################################################################################

# version format YY.MM.DD
version=26.04.27
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Check presense of email and/or password in data breaches"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="e:E:d:pdvh?"

# variables
breach_output="/tmp/$(echo $my_name|cut -d. -f1).txt"
email_ep="https://api.xposedornot.com/v1/check-email"
password_ep="https://passwords.xposedornot.com/api/v1/pass/anon"
domain_ep="https://api.xposedornot.com/v1/breaches?domain="
email_detail_ep="https://api.xposedornot.com/v1/breach-analytics?email="

email=""
email_breached=0
domain=""
password_k_anon=""
args=0

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -e <email>   ---> email address to check against past breached data
  -E           ---> Same as above in addition, shows more details on each breach where email was exposed
  -p           ---> password to check for presense on breached data [will be prompted to enter password]
  -s <domain>  ---> check for all breaches of a specific domain ex: linkedin.com
  -v           ---> enable verbose, otherwise just errors are printed
  -h           ---> print usage/help

Examples: 
  $my_name -f test@example.com
  $my_name -d -f test@example.com [Same as above except list all details of breach where email is found]
  $my_name -p [Note: you will be prompted to enter password]
  $my_name -d linkedin.com

See also: ismalicious.sh ipabuse.sh dns_rebind_check.sh 

EOF
  exit 0
}

read_password() {
  read -s -p "Enter password to check: " password
  echo

  # compute the k-anonimity hash
  password_k_anon=$(printf '%s' "$password" | keccak-512sum - | awk '{print substr($1,1,10)}')
}

check_email() {
  log.stat "Checking $email on all known data breaches ..."
  curl -s ${email_ep}/${email} | jq > $breach_output

  # If the email is present then it is confirmed that it is found in breach
  email_return=$(cat $breach_output | jq -r '.email')

  if [ -z "$email_return" ] || [ "$email_return" = "null" ]  ; then
    log.stat "  Congrats, your email is not found on any of the past data breaches!" $green 
  else
    breaches=$(cat $breach_output | jq -r '.breaches[0] | join(", ")')  
    log.error "  Your email, $email_return is exposed on the following breaches below!"
    log.stat  "  Breaches: $breaches"
    email_breached=1
  fi
}

check_email_detail() {
  check_email
  # now check for expossure details only if the email was found in breach
  if [ $email_breached -eq 1 ] ; then
    log.stat "Checking for details of each breach the email is found..."
    curl -s ${email_detail_ep}${email} | jq -r '.ExposedBreaches'
  fi
}

check_password() {
  read_password
  log.stat "Checking k-anonymity hash ${password_k_anon} of your password on past data breaches ..."

  curl -s ${password_ep}/${password_k_anon} | jq > $breach_output
  count=$(cat $breach_output | jq -r '.SearchPassAnon.count')
  if [ -z "$count" ] || [ $count = "null" ] ; then
    log.stat "  Congrats, your password is not leaked on any of the data breaches!" $green
  else
    log.error "  Your password is found $count times on past data breaches!"
  fi
}

check_domain() {
  log.stat "Checking for breaches of $domain ..."
  curl -s ${domain_ep}${domain} | jq
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

# enforce we are running macOS
check_mac

# enforce required tools are presetnt
check_installed sha3sum
check_installed jq

create_writable_file $breach_output

# parse commandline options
while getopts $options opt ; do
  case $opt in
    e)
      args=1
      email="$OPTARG"
      check_email
      ;;
    E)
      args=1
      email="$OPTARG"
      check_email_detail
      ;;
    p)
      args=1
      check_password
      ;;
    d)
      args=1
      domain="$OPTARG"
      check_domain
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# if no args provided print usage
if [ $args -eq 0 ] ; then
  usage
fi
