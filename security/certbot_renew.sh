#!/bin/bash
#
#
# certbot_renew.sh --- simple wrapper script certbot renewal of my domains
#
# Author:  Arul Selvan
# Version: Oct 24, 2018
#

options_list="hle:d:"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

# note: no need to add acme_server argument to certbot as it defaults to this. This is here for reference
#acme_server="--server https://acme-v02.api.letsencrypt.org/directory"
#certbot_args="-agree-tos --manual-public-ip-logging-ok --preferred-challenges=dns $acme_server"
my_email=""
certbot_args="--agree-tos --manual-public-ip-logging-ok --preferred-challenges=dns"
certbot_bin="/usr/bin/certbot"
domain_list="selvans.net selvansoft.com mypassword.us"

usage() {
  echo "Usage: $my_name [options]"
  echo "  -l list existing certs on the server this script is run and exit"
  echo "  -e <email> email address [note: required argument]"
  echo "  -d <domain(s)> do a single domain or space separated domains. Default: \"$domain_list\""
  echo "  -h usage"
  exit
}

list_certs() {
  echo "[INFO] existing certs are below..." | tee -a $log_file
  $certbot_bin certificates 2>&1 | tee -a $log_file
  exit
}


echo "[INFO] `date`: $my_name log ..." > $log_file
# --------------- main ----------------------
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
    h)
      usage
      ;;
  esac
done

# ensure we have e-mail address
if [ -z $my_email ] ; then
  echo "[ERROR] missing argument! email address is required for renewing certs" | tee -a $log_file
  usage
fi

# some documentation
echo "-------------------------- README --------------------------"
echo "Each domain renewal requres 2 TXT records. For some reason, "
echo "the first record is pretty quick but the second one takes   "
echo "a while to be available, so wait at aleast 30 min to ensure "
echo "the second TXT record shows up in DNS query                 "
echo "------------------------------------------------------------"
echo

# confrim before renewal of each domain
for d in $domain_list ; do
  echo "[INFO] ########## About to renew domain: '$d' ########## " | tee -a $log_file
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    echo "[INFO] renewing certs for domanin: $d" | tee -a $log_file
    echo "[INFO] update DNS records on $d when prompted and hit enter to continue..." | tee -a $log_file
    echo "[INFO] ### NOTE: it may take upto 30min for DNS record to update, so give plenty of time beore continuiing!" | tee -a $log_file
    $certbot_bin certonly --manual -d *.$d -d $d $certbot_args --email $my_email 2>&1 | tee -a $log_file
  else
    echo "[INFO] skiping renewal of domain '$d'" | tee -a $log_file
  fi
done
