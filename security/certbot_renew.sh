#!/usr/bin/env bash
################################################################################
# certbot_renew.sh --- simple wrapper script certbot renewal of my domains
#
# Author:  Arul Selvan
# Version: Oct 24, 2018
################################################################################
# Version History:
#   Oct 24, 2018 --- Original version
#   Aug 12, 2025 --- Removed mypassword.us since we don't want to renew anymore
################################################################################

# version format YY.MM.DD
version=25.08.12
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper script certbot renewal of one or more domains"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="le:d:vh?"

# note: no need to add acme_server argument to certbot as it defaults to this. This is here for reference
#acme_server="--server https://acme-v02.api.letsencrypt.org/directory"
#certbot_args="-agree-tos --manual-public-ip-logging-ok --preferred-challenges=dns $acme_server"
my_email=""
certbot_args="--agree-tos --manual-public-ip-logging-ok --preferred-challenges=dns"
#domain_list="selvans.net selvansoft.com mypassword.us"
domain_list="selvans.net selvansoft.com"

usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -e <email> ---> email address used at LetsEncrypt when cert created [required argument]
  -d <list>  ---> list of single or space separated domains. [Default: "$domain_list"]
  -l         ---> list existing certs on the server this script is run and exit
  -v         ---> enable verbose, otherwise just errors are printed  
  -h usage
EOF
  exit 0
}

list_certs() {
  log.stat "existing certs are below..."
  certbot certificates 2>&1 | tee -a $log_file
  exit
}


# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    l)
      list_certs
      ;;
    e)
      my_email=$OPTARG
      ;;
    d)
      domain_list="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# ensure we have e-mail address
if [ -z $my_email ] ; then
  log.error "Missing argument: email address is required for renewing certs, see usage"
  usage
fi

# some documentation
log.stat "--------------------------------- README ---------------------------------"
log.stat "Each domain renewal requres 2 TXT records. For some reason, " $grey
log.stat "the first record is pretty quick but the second one takes   " $grey
log.stat "a while to be available, so wait at aleast 30 min to ensure " $grey
log.stat "the second TXT record shows up in DNS query                 " $grey
log.stat ""
log.stat "NOTE: Added CAA records to selvans.net DNS to ensure only letsencrypt.org" $blue
log.stat "can issue certs. If there are issues in renewing, remove those records"    $blue
log.stat "--------------------------------------------------------------------------" 
log.stat ""

# confrim before renewal of each domain
for d in $domain_list ; do
  log.stat "########## About to renew domain: '$d' ########## " $grey
  read -p "Are you sure? (y/n) " -n 1 -r
  log.stat ""
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    log.stat "renewing certs for domanin: $d"
    log.stat "Update DNS records on $d when prompted and hit enter to continue..."
    log.stat "NOTE: it may take upto 30min for DNS record to update, so give plenty of time beore proceeding." $yellow
    certbot certonly --manual -d *.$d -d $d $certbot_args --email $my_email 2>&1 | tee -a $my_logfile
  else
    log.stat "skiping renewal of domain '$d'"
  fi
done
