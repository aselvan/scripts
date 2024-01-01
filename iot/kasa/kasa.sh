#!/usr/bin/env bash
#
# kasa.sh --- Turn on/off kasa devices using kasa API
#
# Simple wrapper script for kasa (TPlink) IoT devices using tplink interface APIs 
# This macOS and Linux, if you are on winblows, it might work w/ Cygwin but good 
# luck with that. This is only tested w/ kasa LB100 & KL110 since those are the bulbs
# I have at home.
#
# Credits:
#   https://github.com/michalmoczynski/homeassistant-tplink-integration
#   https://docs.joshuatz.com/random/tp-link-kasa/
#
# Prereq:
# ------
#   macOS: brew install jq 
#   Linux: apt-get install jq 
#
# Notes:
# ------
# All kasa APIs require  token which is valid for some unknown time. Since the token is 
# long and inconvenient to type to invoke calls everytime i.e. convenience over security :)
# the script will look for them in the following location (may be encrypt it openssl?). Anyway,
# if token is expried, script will get a fresh token using user/password which are read from
# ~/.kasarc file (again convenience over security) and store it in $KASA_HOME/.kasa.token
#
# $KASA_HOME/.kasarc
# $KASA_HOME/.kasa.token
# $KASA_HOME/kasa_devices.json    <<< list of devices found will be written to this file
# $KASA_HOME/<device_alias>.json  <<< status of the device as returned by status API
#
# Note: KASA_HOME env variable is not set, it will default to $HOME/kasa
#
# Author:  Arul Selvan
# Version: Jun 21, 2022
#

# version format YY.MM.DD
version=23.12.31
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Turn on/off kasa devices using kasa API"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="a:e:lsvh"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

os_name=`uname -s`
# token expiration secs i.e. 24hrs, although the token seem to work more than a day
token_expiry=86400
device_list_expiry=864000 # 10 days
stat_cmd="stat -f %m"
KASA_HOME=${KASA_HOME:=$HOME/kasa}
kasa_api_ep="https://wap.tplinkcloud.com"
#kasa_api_ep="https://aps1-wap.tplinkcloud.com"
#kasa_api_ep="https://use1-wap.tplinkcloud.com"
device_id=""
device_api_ep=""
kasa_rc="$KASA_HOME/.kasarc"
kasa_token_file="$KASA_HOME/.kasa.token"
kasa_devices_file="$KASA_HOME/kasa_devices.json"
curl_resp_file="/tmp/${my_name}_curl_response.txt"
uuid=`uuidgen`
kasa_token=""
http_status=0
error_code=0
state=""
device_status=0
device_alias=""
device_alias_list=""
verbose=0

usage() {
  cat << EOF
$my_name - $my_title
Usage: $my_name [options]
  -a <list> ---> one or more comma separated alias name of the device(s) to enable [ex: bulb1,bulb2]
  -e <1|0>  ---> enable 1=on, 0=off
  -s        ---> status
  -l        ---> list all the Kasa IoT device alias names in your account
  -v        ---> enable verbose, otherwise just errors are printed
  -h        ---> print usage/help
  
  example: $my_name -a "bulb1, bulb2" -e 1

EOF
  exit 0
}

check_http_status() {
  http_code=$1

  # add all http codes here, later.
  case $http_code in 
    200)
      # kasa API is dumb, returns 200 for failures @#~!
      error_code=`cat $curl_resp_file | jq -r '.error_code'`
      if [ $error_code -eq 0 ] ; then
        return
      fi
      error_msg=`cat $curl_resp_file | jq -r '.msg'`      
      log.error "Kasa API returned error_code='$error_code' for device='$device_alias'; error_message='$error_msg'"
      ;;
    401)
      log.error "http 401 unauthorized, expired token or bad user/password?"
      ;;
    *)
      log.error "http $http_code unknown error!"
      ;;
  esac
  exit 1
}

check_parms() {
  if [ -f $kasa_rc ]; then
    source $kasa_rc
    if [ -z $user ] || [ -z $password ] ; then
      log.error "File \"$kasa_rc\" is missing required user, password variables!"
      usage
    fi
  else
    log.error "no $kasa_rc file found! Create it manually with the two lines as shown below ..."
cat <<EOF
user="username"
kasa_password="password"
EOF
    usage
  fi
}

get_token_request() {
  cat <<EOF
  {
    "method" : "login",
    "params" : {
      "appType": "Kasa_Android",
      "cloudUserName": "$user",
      "cloudPassword": "$password",
      "terminalUUID": "$uuid"
    }
  }
EOF
}

get_devicelist_request() {
  cat <<EOF
  {
    "method" : "getDeviceList",
    "params" : {
      "appType": "Kasa_Android",  
      "terminalUUID": "$uuid",
      "token": "$kasa_token"
    }
  }
EOF
}

get_state_request() {
  cat <<EOF
  {
    "method" : "passthrough",
    "params" : {
      "appType": "Kasa_Android",      
      "terminalUUID": "$uuid",
      "token" : "$kasa_token",
      "deviceId" : $device_id,
      "requestData" : "{ \"smartlife.iot.smartbulb.lightingservice\":{ \"transition_light_state\": { \"on_off\": $state, \"mode\": \"normal\"}}}"
    }
  }
EOF
}

get_status_request() {
  cat <<EOF
  {
    "method" : "passthrough",
    "params" : {
      "appType": "Kasa_Android",
      "terminalUUID": "$uuid",
      "token" : "$kasa_token",
      "deviceId" : $device_id,
      "requestData" : "{\"system\": { \"get_sysinfo\": null }}"
    }
  }
EOF
}

get_status() {
  log.info "get status for device ($device_alias) ..."
  
  # find the deviceId
  query=".result.deviceList[] | select(.alias == \"$device_alias\").deviceId"
  device_id=`cat $kasa_devices_file | jq "$query"`

  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_status_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status

  cat $curl_resp_file | jq '.result.responseData | fromjson' >  ${KASA_HOME}/$device_alias.json
  echo "Device '$device_alias' status is written to the file '${KASA_HOME}/$device_alias.json'"
}

set_state() {
  # find the deviceId
  query=".result.deviceList[] | select(.alias == \"$device_alias\").deviceId"
  device_id=`cat $kasa_devices_file | jq "$query"`
  if [ -z $device_id ] ; then
    log.error "device alias '$device_alias' is invalid or non-existent!"
    exit 3
  fi

  # note: the generic API $kasa_api_ep seem to work just, not sure why a specicic 
  # API EP for now we simply use single EP for all
  #query=".result.deviceList[] | select(.alias == \"$device_alias\").appServerUrl"
  #device_api_ep=`cat $kasa_devices_file | jq "$query"`

  log.info "seting device ($device_alias) to state: $state ..."
  
  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_state_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  if [ $verbose -eq 1 ] ; then
    cat $curl_resp_file | jq '.result.responseData | fromjson'
  fi
  log.info "successfully set the state to $state on device '$device_alias'!"
}

get_devicelist() {

  # read if there is existing devicelist and check if it is not stale i.e. >10 days
  log.info "retrieve device list ..."
  if [ -f $kasa_devices_file ] ; then
    device_list_duration=$(( `date +'%s'` - `$stat_cmd $kasa_devices_file` ))
    if [ $device_list_duration -lt $device_list_expiry ]; then
      return
    fi
  fi

  log.info "existing deviceList file is too old or does not exist, so getting a new list ..."
  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_devicelist_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  
  cat $curl_resp_file |  jq -S  > $kasa_devices_file
}

get_new_token() {
  log.info "kasa token is not present or expired, getting fresh token ..."
  
  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_token_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  
  kasa_token=`cat $curl_resp_file | jq -r '.result.token'`
  echo $kasa_token > $kasa_token_file
}

get_token() {
  # read token file if present, and ensure the timestamp is not greater than expiry time
  if [ -f $kasa_token_file ] ; then
    token_duration=$(( `date +'%s'` - `$stat_cmd $kasa_token_file` ))
    if [ $token_duration -gt $token_expiry ]; then
      get_new_token
    else
      kasa_token=`cat $kasa_token_file`
    fi
  else
    get_new_token
  fi
}

get_device_list() {
  log.stat "Kasa IoT devices found on your account are listed below..."
  cat $kasa_devices_file | jq -r '.result.deviceList[] | .alias, .deviceId, .deviceModel' | while 
    read -r a; read -r i; read -r m; do 
      log.stat "  alias: $a; Model: $m; Id: $i" $grey
    done
  exit 0
}

init() {
  # check for kasarc file and read user/password
  check_parms

  # read or get new token
  get_token

  # get device list
  get_devicelist
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

if [ $os_name != "Darwin" ]; then
  stat_cmd="stat -c %Y"
fi

# initialize
init

# commandline parse
while getopts $options opt; do
  case $opt in
    a)
      device_alias_list=$OPTARG
      ;;
    s)
      device_status=1
      ;;
    l)
      get_device_list
      ;;
    e)
      state=$OPTARG
      if [ $state -ne 1 ] && [ $state -ne 0 ] ; then
        log.error "invalid state '$state', state must be either 0 or 1 "
        usage
      fi
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done


if [ -z "$device_alias_list" ] ; then
  log.error "missing device alias name!"
  usage
fi

# just status?
if [ $device_status -ne 0 ] ; then
  # get status and exit
  for a in $(echo $device_alias_list|sed 's/,/ /g') ; do
    device_alias=$a
    get_status
  done
  exit 0 
fi

# set state?
if [ -z $state ] ; then
  log.error "required argument for enable missing!"
  usage
fi

# go through a single or list of devices provided and turn on/off
for a in $(echo $device_alias_list|sed 's/,/ /g') ; do
  device_alias=$a
  set_state
done

exit 0

