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
# Created: Aug 7, 2019
#
# Version History:
#   Aug 7,  2019 --- Orginal version (from ~/.bashrc) moved to standalone script
#   May 19, 2024 --- Added options, validate chain, list chain error check etc.
#   Dec 6,  2024 --- Added validation for CN/SAN.
#   Dec 12, 2024 --- Option to save the SSL cert to a file
#

# version format YY.MM.DD
version=24.12.12
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Download and validate SSL certs of a server"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:d:o:x:lvh?"

optional_checks=""
show_ssl_chain=0
chain_depth=5
server=""
pem_path_prefix="/tmp/$(echo $my_name|cut -d. -f1)"
openssl_version_30x=0
ls_opt="-1t"
first_cert_name=""
last_cert_name=""
ssl_cert_file=""

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -s <server> ---> webserver who's SSL cert needs to be validated
  -d <number> ---> chain depth [default: $chain_depth is sufficient for most cases]
  -o <flags>  ---> Any openssl x509 flags example "-enddate -issuer -subject -fingerprint"
  -l          ---> list ssl chain starting from root -> server cert
  -x          ---> filename to store the extracted cert
  -c          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -s google.com -o "-enddate -issuer"
  
EOF
  exit 0
}

# NOTE: need to reverse the certs for older openssl version. As per ChatGPT openssl version
# at or below 3.0.10 lists order of certs starting with server,intermediate,root which 
# doesn't work for openssl verify. Need to change sort order accordingly
check_openssl_version() {
  local openssl_version=`openssl version |awk  '{ print $2; }'`
  if version_le "$openssl_version" "3.0.10" ; then
    log.warn "  Openssl version is old: v${openssl_version}"
    ls_opt="-1rt"
    openssl_version_30x=1
  fi
}

list_ssl_chain() {
  if [ $show_ssl_chain -eq 0 ] ; then
    return
  fi
  log.stat "  SSL cert chain list:"
  local n=0
  for f in `ls $ls_opt ${pem_path_prefix}_?.pem` ; do
    local result=`openssl x509 -in $f -noout -subject -issuer|tr '\n' ' ,'`
    log.stat "    $n: $result" $black
    ((++n))
  done
}

validate_ssl_chain() {
  log.stat "Validating SSL cert chain for server: $server"

  # make sure there aren't any old *.pem siting around from prev runs
  rm -f ${pem_path_prefix}*.pem
  
  openssl s_client -showcerts -verify $chain_depth -connect $server:443 < /dev/null 2>/dev/null | awk -v path="${pem_path_prefix}" '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){n++}; out=path "_" n ".pem"; print >out}'
  status_list=( ${PIPESTATUS[*]} )
  if [ ${status_list[0]} -ne 0 ] ; then
    log.error "  Timeout connecting to server $server ... exiting"
    exit 1
  elif [ ${status_list[1]} -ne 0 ] ; then
    log.error "  Error reading certs from server $server ... exiting"
    exit 2
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
    log.error "\tWARNING: At least one intermediate cert in the cert chain is invalid!"
  else
    log.stat  "\tSSL certs are valid for: $server" $green
  fi
}

# validate Subject Alternative Name (SAN)
validate_san() {
  log.stat "Validatin CN (Common Name) for server: $server"

  local cert_info=$(openssl s_client -connect "${server}:443" -servername "${server}" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName)
  local subject=$(echo "${cert_info}" | grep "subject=" | sed 's/^subject= //')
  local san=$(echo "${cert_info}" | grep -o "DNS:[^,]*" | sed 's/DNS://g')
  local match_found=false

  if [[ "${server}" == "$(echo ${subject} | grep -o 'CN=[^,]*' | sed 's/CN=//')" ]]; then
    match_found=true
  else
    for name in ${san}; do
      if [[ "${server}" == "${name}" || "${name}" == "*.${server#*.}" ]]; then
        match_found=true
        break
      fi
    done
  fi

  if [ "${match_found}" = true ]; then
    log.stat  "\tThe CN name ($subject) matches $server" $green
  else
    log.error "\tWARNING: CN ($subject) failed to match $server"
  fi
}

additional_options() {
  if [ -z "$optional_checks" ] ; then
    return
  fi

  # pick the right cert for the sever (not cert from intermediate chain)
  local cert_name=""
  if [ $openssl_version_30x -eq 1 ] ; then
    openssl x509 -in $last_cert_name $optional_checks -noout
  else
    openssl x509 -in $first_cert_name $optional_checks -noout
  fi
}

extract_ssl_cert() {
  echo | openssl s_client -connect ${server}:443 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >$ssl_cert_file
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
    l)
      show_ssl_chain=1
      ;;
    x)
      ssl_cert_file="$OPTARG"
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

check_openssl_version

# if this is just to extract, do the extract and exit
if [ ! -z $ssl_cert_file ] ; then
  extract_ssl_cert
  exit 0
fi

validate_ssl_chain
list_ssl_chain
validate_san
additional_options


