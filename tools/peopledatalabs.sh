#!/usr/bin/env bash

# 
# script to check public data of anyone listed in PDL (peopledatalabs.com) database
#
# Author:  Arul Selvan
# Version: Nov 23, 2019
#

# replace your API key here [note: get a free that does 1000 calls/month from peopledatalabs.com)
api_key=`cat ~/.peopledatalabs.apikey`

# commandline options
options_list="e:p:n:l:h"

version=19.11.23
my_name="`basename $0`"
my_version="`basename $0` v$version"

usage() {
  echo "Usage: $my_name -e <e-mail> | -p <profile> | -n <name> -l <location>"
  echo "  ex: $my_name -n "John+Public" -l "Texas" "
  exit 1
}

#peopledatalabs_api="https://api.peopledatalabs.com/v4/person?pretty=true"
peopledatalabs_api="https://api.peopledatalabs.com/v5/person/identify?pretty=true"
curl_args=( -X GET -H \"X-Api-Key: $api_key\" )
#api_query="&name=John+Public&location=texas"

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
    h)
     usage
     ;;
    :)
     echo "Option -$OPTARG requires and argument."
     usage
     ;;
   esac
done

echo $my_version
curl -X GET -H "X-Api-Key: $api_key" "$peopledatalabs_api$api_query"
