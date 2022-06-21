#!/bin/bash
#
# kasa.sh
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
# $KASA_HOME/kasa_devices.json <<< List of devices found
#
# Note: KASA_HOME env variable is not set, it will default to $HOME/kasa
#
# Author:  Arul Selvan
# Version: Jun 21, 2022
#
my_name=`basename $0`
os_name=`uname -s`
# token expiration secs i.e. 24hrs, although the token seem to work more than a day
token_expiry=86400
device_list_expiry=864000 # 10 days
options="a:e:lsh"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
jq_bin=/usr/local/bin/jq
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

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -a <device_alias> ---> alias name of the device to enable [ex: mybulb1]"
  echo "  -e <1|0>          ---> enable 1=on, 0=off"
  echo "  -s                ---> status"
  echo "  -l                ---> list all the Kasa IoT device alias names in your account"
  echo ""
  echo "example: $my_name -a "mybulb1" -e 1"
  echo ""
  exit 0
}

log() {
  message_type=$1
  message=$2
  echo "$message_type $message" | tee -a $log_file
}

check_http_status() {
  http_code=$1

  # add all http codes here, later.
  case $http_code in 
    200)
      # kasa API is dumb, returns 200 for failures @#~!
      error_code=`cat $curl_resp_file | $jq_bin -r '.error_code'`
      if [ $error_code -eq 0 ] ; then
        return
      fi
      error_msg=`cat $curl_resp_file | $jq_bin -r '.msg'`      
      log "[ERROR]" "Kasa API returned error_code='$error_code'; error_message='$error_msg'"
      ;;
    401)
      log "[ERROR]" "http 401 unauthorized, expired token or bad user/password?"
      ;;
    *)
      log "[ERROR]" "http $http_code unknown error!"
      ;;
  esac
  exit
}

check_parms() {
  if [ -f $kasa_rc ]; then
    source $kasa_rc
    if [ -z $user ] || [ -z $password ] ; then
      log "[ERROR]" "File \"$kasa_rc\" is missing required user, password variables!"
      usage
    fi
  else
    log "[ERROR]" "no $kasa_rc file found! Create it manually with the two lines as shown below ..."
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
  log "[INFO]" "get status for device ($device_alias) ..."
  
  # find the deviceId
  query=".result.deviceList[] | select(.alias == \"$device_alias\").deviceId"
  device_id=`cat $kasa_devices_file | $jq_bin "$query"`

  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_status_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  cat $curl_resp_file | $jq_bin
  log "[INFO]" "successfully retrieved the status for device '$device_alias'"  
}

set_state() {
  # find the deviceId
  query=".result.deviceList[] | select(.alias == \"$device_alias\").deviceId"
  device_id=`cat $kasa_devices_file | $jq_bin "$query"`
  query=".result.deviceList[] | select(.alias == \"$device_alias\").appServerUrl"
  device_api_ep=`cat $kasa_devices_file | $jq_bin "$query"`

  log "[INFO]" "seting device ($device_alias) to state: $state ..."
  
  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_state_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  cat $curl_resp_file | $jq_bin
  log "[INFO]" "successfully set the state to $state on device '$device_alias'!"
}

get_devicelist() {

  # read if there is existing devicelist and check if it is not stale i.e. >10 days
  log "[INFO]" "retrieve device list ..."
  if [ -f $kasa_devices_file ] ; then
    device_list_duration=$(( `date +'%s'` - `$stat_cmd $kasa_devices_file` ))
    if [ $device_list_duration -lt $device_list_expiry ]; then
      return
    fi
  fi

  log "[INFO]" "existing deviceList file is too old or does not exist, so getting a new list ..."
  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_devicelist_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  
  cat $curl_resp_file |  $jq_bin -S  > $kasa_devices_file
}

get_new_token() {
  log "[INFO]" "kasa token is not present or expired, getting fresh token ..."
  
  http_status=`curl -s -H "Content-Type:application/json" -X POST \
    --data "$(get_token_request)" \
    -w "%{http_code}" \
    -o $curl_resp_file \
    "$kasa_api_ep"`

  check_http_status $http_status
  
  kasa_token=`cat $curl_resp_file | $jq_bin -r '.result.token'`
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
  echo "[INFO] List of Kasa IoT devices found listed below:"
  cat $kasa_devices_file | $jq_bin -r '.result.deviceList[] | .alias, .deviceId, .deviceModel' | while 
    read -r a; read -r i; read -r m; do 
      echo -e "\talias: $a; Model: $m; Id: $i"
    done
  exit
}

init() {
  # check for kasarc file and read user/password
  check_parms

  # read or get new token
  get_token

  # get device list
  get_devicelist
}

# ----------  main --------------
echo "[INFO] `date`: Starting $my_name ..." > $log_file
if [ $os_name != "Darwin" ]; then
  jq_bin=/usr/bin/jq
  stat_cmd="stat -c %Y"
fi

# initialize
init

# commandline parse
while getopts $options opt; do
  case $opt in
    a)
      device_alias=$OPTARG
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
        log "[ERROR]" "invalid state '$state', state must be either 0 or 1 "
        usage
      fi
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done


if [ -z $device_alias ] ; then
  log "[ERROR}" "missing device alias name!"
  usage
fi

if [ $device_status -ne 0 ] ; then
  # get status and exit
  get_status
  exit
fi

# set state
if [ -z $state ] ; then
  log "[ERROR]" "required argument for enable missing!"
  usage
else
  set_state
fi
