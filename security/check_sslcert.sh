#!/usr/bin/env bash
#
# check_sslcert.sh --- Download and validate SSL certs of a server
#
# Validation is done by downloading all the certificates in the certificate 
# chain. Optionally, you print the expiration date, issuer etc. The script
# uses openssl binary so it is a requirement but both Linux & MacOS should
# have openssl
#
# Author:  Arul Selvan
# Created: May 18, 2024
#
# Version History:
#   May 18, 2024 --- Initial version.
#

# version format YY.MM.DD
version=25.05.18
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Download and validate SSL certs of a server"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:d:o:vh?"

optional_checks=""
chain_depth=5
server=""
pem_path_prefix="/tmp/$(echo $my_name|cut -d. -f1)"
openssl_version=`openssl version |awk  '{ print $2; }'`
ls_opt="-1t"
first_cert_name=""
last_cert_name=""

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -s <server> ---> webserver who's SSL cert needs to be validated
  -d <number> ---> chain depth [default: $chain_depth is sufficient for most cases]
  -o <flags>  ---> Any openssl x509 flags example "-enddate -issuer -subject -fingerprint"
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -s google.com -o "-enddate -issuer -subject"
  
EOF
  exit 0
}

validate_ssl_chain() {
  log.stat "Validating SSL cert chain for '$server'"

  # make sure there aren't any old *.pem siting around from prev runs
  rm -f ${pem_path_prefix}*.pem
  
  openssl s_client -showcerts -verify $chain_depth -connect $server:443 < /dev/null 2>/dev/null | awk -v path="${pem_path_prefix}" '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){n++}; out=path "_" n ".pem"; print >out}'
  

  # need to reverse the certs for older openssl version. Not clear when openssl started 
  # provide chain certs in reverse order which is needd for verify to work but older version
  # 3.0x need to have order reversed (correct order is root, intermediate, & server certs)
  if [[ $openssl_version = "3.0"* ]] ; then
    log.debug "  reversing order of certificate chain"
    ls_opt="-1rt"
  fi
  local list=""
  first_cert_name="${pem_path_prefix}_1.pem"
  for f in `ls $ls_opt ${pem_path_prefix}_?.pem` ; do
    list="$list $f"
    last_cert_name=$f
  done
  cat $list > ${pem_path_prefix}_all.pem

  # validate
  openssl verify ${pem_path_prefix}_all.pem >> $my_logfile 2>&1
  if [ $? -ne 0 ] ; then
    log.error "  One or more intermediate certificate in the chain is invalid!"
  else
    log.stat "  SSL certs are valid for: $server" $green
  fi
}

additional_options() {
  if [ -z "$optional_checks" ] ; then
    return
  fi

  # pick the right cert for the sever (not cert from intermediate chain)
  local cert_name=""
  if [[ $openssl_version = "3.0"* ]] ; then
    openssl x509 -in $last_cert_name $optional_checks -noout
    log.debug "  using certname $last_cert_name"
  else
    openssl x509 -in $first_cert_name $optional_checks -noout
    log.debug "  using certname $first_cert_name"
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
check_installed "openssl"

# parse commandline options
while getopts $options opt ; do
  case $opt in
    s)
      server="$OPTARG"
      ;;
    d)
      chain_depth="$OPTARG"
      ;;
    o)
      optional_checks="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$server" ] ; then
  log.error "Required argument missing! See usage below"
  usage
fi

validate_ssl_chain
additional_options

