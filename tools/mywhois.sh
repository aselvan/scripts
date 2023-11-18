#!/usr/bin/env bash
#
# mywhois.sh --- parse whois output and print in simple form. 
#
# You can optionally select specific items (registrant contact,
# admin contact, tech contact etc) by default it prints just the 
# domain information.
#
# Author:  Arul Selvan
# Created: Jul 24, 2023
#

# version format YY.MM.DD
version=23.11.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="d:ratvh?"

whois_file="/tmp/$(echo $my_name|cut -d. -f1).txt"
domain_name=""
print_registrant=0
print_admin_contact=0
print_tech_contact=0
whois_error="An error occurred. Please try again later"
whois_interval=3
whois_attempts=2

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

check_whois_error() {
  grep -q "$whois_error" $whois_file 2>&1 >/dev/null
  return $?
}

usage() {
cat << EOF

Usage: $my_name [options]
  -d <domain> ---> domain to query whois db
  -r          ---> print registrant contact [optional]
  -a          ---> print adminstrative contact [optional]
  -t          ---> print technical contact [optional]
  -h          ---> print usage/help

example: $my_name -d selvansoft.com -r
  
EOF
  exit 0
}

print_domain_info() {
  echo ""
  echo "---------- Domain Information ($domain_name) ----------"
  dname=$(grep 'Domain Name:' $whois_file | cut -d: -f2-)
  echo "Domain:" $dname
  registrar=$(grep 'Registrar:' $whois_file | cut -d: -f2-)
  echo "Registrar:" $registrar
  create_date=$(grep 'Creation Date:' $whois_file | cut -d: -f2-)
  echo "Creation Date:" $create_date
  expire_date=$(grep 'Registrar Registration Expiration Date:' $whois_file | cut -d: -f2-)
  if [ -z "$expire_date" ] ; then
    expire_date=$(grep 'Registry Expiry Date:' $whois_file | cut -d: -f2-)
  fi
  echo "Expiration Date:" $expire_date
  updated_date=$(grep 'Updated Date:' $whois_file | cut -d: -f2-)
  echo "Updated Date:" $updated_date
  #status=$(grep 'Domain Status:' $whois_file | cut -d: -f2-)
  #echo "Domain Status:"
  #echo "$status"
  name_servers=$(grep 'Name Server:' $whois_file | cut -d: -f2-)
  echo "Name Servers:"
  echo "$name_servers"
}

print_optional_info() {
  option=$1  
  echo "---------- $option Contact ($domain_name) ---------- "
  name=$(grep "$option Name:" $whois_file| cut -d: -f2-)
  echo "Name:" $name
  org=$(grep "$option Organization:" $whois_file| cut -d: -f2-)
  echo "Organization:" $org
  street=$(grep "$option Street:" $whois_file | cut -d: -f2-)
  echo "Street:" $street
  city=$(grep "$option City:" $whois_file | cut -d: -f2-)
  echo "City:" $city
  state=$(grep "$option State/Province:" $whois_file | cut -d: -f2-)
  echo "State:" $state
  zip=$(grep "$option Postal Code:" $whois_file | cut -d: -f2-)
  echo "Zip:" $zip
  country=$(grep "$option Country:" $whois_file | cut -d: -f2-)
  echo "Country:" $country
  phone=$(grep "$option Phone:" $whois_file | cut -d: -f2-)
  echo "Phone:" $phone
  email=$(grep "$option Email:" $whois_file| cut -d: -f2-)
  echo "E-mail:" $email
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    d)
      domain_name="$OPTARG"
      ;;
    r)
      print_registrant=1
      ;;
    a)
      print_admin_contact=1
      ;;
    t)
      print_tech_contact=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $domain_name ] ; then
  log.error "ERROR: missing domain to query for!"
  usage
fi

# get the whois record and strip CRs at the same time.
whois $domain_name 2>&1 | tr -d '\r' > $whois_file
registrar_server=`cat $whois_file | grep "Registrar WHOIS Server:" | head -n1 | awk '{print $4'}`
if [ ! -z $registrar_server ] ; then
  # get records from registrar server instead
  log.stat "Using registrar server '$registrar_server' to query for '$domain_name' records..."
  sleep $whois_interval
  whois -h $registrar_server $domain_name 2>&1 | tr -d '\r' > $whois_file
  ntry=0
  while check_whois_error ; do
    log.warn "Whois command is throttling... sleeping $whois_interval secs & try again..."
    sleep $whois_interval
    whois -h $registrar_server $domain_name 2>&1 | tr -d '\r' > $whois_file
    ntry=$((ntry+1))
    if [ $ntry -gt $whois_attempts ] ; then
      log.error "Whois command continues to block... try again later."
      exit 2
    fi
  done
else
  log.stat "Using default whois server to query for '$domain_name' records..."
fi

# print domain info
print_domain_info

# optional output if requested
if [ $print_registrant -ne 0 ] ; then
  print_optional_info "Registrant"
fi

if [ $print_admin_contact -ne 0 ] ; then
  print_optional_info "Admin"
fi

if [ $print_tech_contact -ne 0 ] ; then
  print_optional_info "Tech"
fi

