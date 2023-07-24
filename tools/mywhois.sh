#!/bin/bash
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
version=23.07.24
my_name="`basename $0`"
my_version="`basename $0` v$version"
os_name=`uname -s`
dir_name=`dirname $0`

whois_file="/tmp/$(echo $my_name|cut -d. -f1).txt"
options="d:rath?"
domain_name=""
print_registrant=0
print_admin_contact=0
print_tech_contact=0

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

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
  echo "---------- Domain Information ----------"
  domain_name=$(grep 'Domain Name:' $whois_file | cut -d: -f2-)
  echo "Domain:" $domain_name
  registrar=$(grep 'Registrar:' $whois_file | cut -d: -f2-)
  echo "Registrar:" $registrar
  create_date=$(grep 'Creation Date:' $whois_file | cut -d: -f2-)
  echo "Creation Date:" $create_date
  expire_date=$(grep 'Registrar Registration Expiration Date:' $whois_file | cut -d: -f2-)
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
  echo "---------- $option Contact ---------- "
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

# ----------  main --------------
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
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $domain_name ] ; then
  echo "ERROR: missing domain to query for!"
  usage
fi

echo "$my_version"
# get the whois record
whois $domain_name 2>&1 > $whois_file
registrar_server=`cat $whois_file | grep "Registrar WHOIS Server:" | head -n1 | awk '{print $4'}`
registrar_server=${registrar_server%$'\r'}
if [ ! -z $registrar_server ] ; then
  # get records from registrar server instead
  whois -h $registrar_server $domain_name 2>&1 > $whois_file
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
