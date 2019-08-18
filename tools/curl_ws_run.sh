#!/bin/bash
#
# Quick wrapper shell script for running a webservice call with client certfificate
#
# Author:  Arul Selvan
# Version: Feb 14, 2013
#
# NOTES: the private key is extracted from mycert.pfx using following command and 'password' 
# as password
# openssl pkcs12 -in mycert.pfx -out mycert.pem -clcerts
#
options_list="r:s:o:"
curl_cmd=/usr/bin/curl
request_file=soap_request.txt
output_file=soap_response.out
certificate="mycert.pem"
curl_args='-k -s --cert $certificate:password --key $certificate -H "Content-Type: text/xml; charset=utf-8" -H "SOAPAction:"'
service="https://host/soapEndpoint"

usage() {
  echo "Usage: $0 [-r <request_file> | -o <output_file> | -s <soap_endpoint>]"
  exit 1
}

while getopts "$options_list" opt; do
  case $opt in
    r)
     request_file=$OPTARG
     ;;
    s)
     service=$OPTARG
     ;;
    o)
     output_file=$OPTARG
     ;;
    \?)
     echo "Invalid option: -$OPTARG"
     usage
     ;;
    :)
     echo "Option -$OPTARG requires and argument."
     usage
     ;;
   esac
done

echo "Service: $service"
echo "Request: $request_file"
echo "Output:  $output_file"

$curl_cmd $curl_args -d @$request_file -X POST $service >$output_file 2>&1
