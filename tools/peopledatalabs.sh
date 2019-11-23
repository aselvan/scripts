#!/bin/bash

# 
# script to check public data of anyone listed in PDL (peopledatalabs.com) database
#
# Author:  Arul Selvan
# Version: Nov 23, 2019
#

# replace your API key here [note: get a free that does 1000 calls/month from peopledatalabs.com)
api_key=`cat ~/.peopledatalabs.apikey`

# commandline options
options_list="e:p:n:l:"

usage() {
  echo "Usage: $0 -e <e-mail> | -p <profile> | -n <name> -l <location>"
  exit 1
}

peopledatalabs_api="https://api.peopledatalabs.com/v4/person?pretty=true"
curl_args=( -X GET -H "X-Api-Key: $api_key" )
api_query="name=Sabrina Rajendran&location=chicago"
api_query=""

while getopts "$options_list" opt; do
  case $opt in
    e)
      api_query="&email=$OPTARG"
      break
      ;;
    p)
      api_query="&profile=$OPTARG"
      break
      ;;
    n)
      api_query="$api_query&name=$OPTARG"
      ;;
    l)
      api_query="$api_query&location=$OPTARG"
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

curl "${curl_args[@]}" "$peopledatalabs_api$api_query"
