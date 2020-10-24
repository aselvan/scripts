#!/bin/bash
#
#
# certbot_renew.sh --- simple wrapper script certbot renewal of my domains
#
# Author:  Arul Selvan
# Version: Oct 24, 2018
#

options_list="hle:"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"

# note: no need to add acme_server argument to certbot as it defaults to this. This is here for reference
#acme_server="--server https://acme-v02.api.letsencrypt.org/directory"
#certbot_args="-agree-tos --manual-public-ip-logging-ok --preferred-challenges=dns $acme_server"
my_email="aselvan@selvans.net"
certbot_args="-agree-tos --manual-public-ip-logging-ok --preferred-challenges=dns"
certbot_bin="/usr/bin/certbot"
domain_list="mypassword.us selvans.net"

usage() {
  echo "Usage: $my_name [options]"
  echo "  -l list existing certs on the server this script is run and exit"
  echo "  -e <email> email address to use for certificate renewal process"
  echo "  -h usage"
  exit
}

list_certs() {
  echo "[INFO] existing certs are below..." | tee -a $log_file
  $certbot_bin certificates 2>&1 | tee -a $log_file
  exit
}

renew_certs() {
  for d in $domain_list ; do
    echo "[INFO] renewing certs for domanin: $d" | tee -a $log_file
    echo "[INFO] update DNS records on $d when prompted and hit enter to continue..." | tee -a $log_file
    $certbot_bin certonly --manual -d *.$d -d $d $certbot_args --email $my_email 2>&1 | tee -a $log_file
  done
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
    h)
      usage
      ;;
  esac
done

# just confrim before renewal
echo "[INFO] about to renew the following domains: $domain_list" | tee -a $log_file
read -p "Are you sure? (y/n) " -n 1 -r
echo 
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  renew_certs
else
  echo "[INFO] renew cancelled" | tee -a $log_file
fi
