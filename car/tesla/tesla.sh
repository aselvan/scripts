#!/bin/bash
#
# tesla.sh
#
# Simple wrapper script for various tesla commands. This script
# is tested on macOS and Linux, if you are on winblows, it might 
# work w/ Cygwin but good luck with that.
#
# prereq:
# ------
# use tesla_token.sh to obtain your bearer token and use this script
# to obtain the vehicle id (use id command).
#
# optional:
# --------
# if jq (jason commandline processor) installed, it will be used to 
# print the output with JSON formatted. You can install it like so below.
#
# brew install jq (macOS)
# apt-get install jq (Linux)
#
# Notes:
# ------
# All tesla APIs require bearer token and vehicle id. Since the token 
# and id are very long and inconvenient to type to invoke calls everytime
# i.e. convenience over security :),  the script will look for them in 
# the following location (may be encrypt it openssl?). Anyway, you need get 
# these onetime and store it the files below for all subsequent usage. 
# The bearer token does expires after 45.
#
# $HOME/.mytesla.bearer.token
# $HOME/.mytesla.vehicle.id
#
# Author:  Arul Selvan
# Version: Jun 6, 2020
#
# API reference: https://tesla-api.timdorr.com/
# Client ID & Secret: https://pastebin.com/pS7Z6yyP
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
jq_bin=/usr/local/bin/jq
tesla_api_ep="https://owner-api.teslamotors.com/api/1"
client_id="81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
client_secret="c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
bearer_token_file="$HOME/.mytesla.bearer.token"
tesla_id_file="$HOME/.mytesla.id"
bearer_token=""
tesla_id=""
os_name=`uname -s`
sleep_time=30

usage() {
  echo "Usage: $my_name <id|state|wakeup|charge|climate|drive|honk|start|sentry|lock|unlock|location|update|log|light}>"
  echo ""
  exit 0
}

log() {
  message_type=$1
  message=$2
  echo "$message_type $message" || tee -a $log_file
}

check_vehicle_id() {
  if [ -z $tesla_id ] ;  then
    log "[ERROR]" "id missing, create the file $tesla_id_file"
    usage
  fi
}

json_print() {
  data=$1
  if [ -x $jq_bin ] ; then
    echo $data | $jq_bin
    if [ $? -ne 0 ] ; then
      # jason format may be messed up on response?
      log "[INFO]" $data
    fi
  else
    log "[INFO]"  $data
  fi
  echo ""
}

# wakeup, tesla!
wakeup() {
  log "[INFO]" "attempting to wake up tesla..."

  # attempt 3 times to wakup and bail if not successful
  for (( i=0; i<3; i++)) ;  do
    response=`curl -s -X POST \
      -H "Cache-Control: no-cache" \
      -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
      -H "Authorization: Bearer $bearer_token" \
      $tesla_api_ep/vehicles/$tesla_id/wake_up 2>&1`
  
    if [[ $response == *state*:*online* ]] ; then
      log "[INFO]" "tesla should be awake now."
      return
    fi

    # not waking up, log output
    # sleep for sometime
    log "[WARN]" "tesla not waking up, will try in $sleep_time sec again. API reponse='$response'"
    sleep $sleep_time

  done

  log "[WARN]" "your tesla had too much to drink, not waking up! Try again later."
}

# execute the command
execute() {
  command_route=$1
  curl_request="GET"
  additional_arg=""
  
  if [ ! -z $2 ] ; then
    curl_request=$2
  fi
  
  if [ ! -z $3 ] ; then
    additional_arg=$3
  fi

  # need to ensure tesla id is present for all commands except "vehicles" to get it
  if [ $command_route != "vehicles" ]; then
    check_vehicle_id
  fi

  # make sure tesla is awake
  wakeup

  log "[INFO]" "executing '$curl_request' on route: $tesla_api_ep/$command_route ..."
  if [ -z $additional_arg ] ; then
    result=`curl -s -X $curl_request \
      -H "Cache-Control: no-cache" \
      -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
      -H "Authorization: Bearer $bearer_token" \
      -w "\n\n" \
      $tesla_api_ep/$command_route`
  else
    result=`curl -s -X $curl_request \
      -H "Cache-Control: no-cache" \
      -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
      -H "Authorization: Bearer $bearer_token" \
      -F "$additional_arg" \
      -w "\n\n" \
      $tesla_api_ep/$command_route`
  fi
  
  json_print "$result"
}

location() {
  if [ ! -x $jq_bin ] ; then
    log "[ERROR]" "jq (JSON commandline processor) required for 'location' command"
    exit 2
  fi

  check_vehicle_id
  wakeup

  result=`curl -s -X GET \
    -H "Cache-Control: no-cache" \
    -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
    -H "Authorization: Bearer $bearer_token" \
    -w "\n\n" \
    $tesla_api_ep/vehicles/$tesla_id/data_request/drive_state`

    lat=`echo $result| $jq_bin '.response.latitude'`
    lon=`echo $result| $jq_bin '.response.longitude'`

    google_map="https://maps.google.com/?q=$lat,$lon"

    # if we are on a macOS, open the link in default browser, otherwise just print
    if [ $os_name = "Darwin" ]; then
      log "[INFO]" "opening tesla location in browser: $google_map"
      /usr/bin/open "$google_map"
    else
      log "[INFO]" "your tesla location URL: $google_map"
    fi
}

# ----------  main --------------
echo "[INFO] `date` Starting $my_name ..." > $log_file

# read bearer token and vehicle id.
if [ -f $bearer_token_file ] ; then
  bearer_token=`cat $bearer_token_file`
fi
if [ -f $tesla_id_file ] ;  then
  tesla_id=`cat $tesla_id_file`
fi

if [ -z $bearer_token ] ; then
  log "[ERROR]" "bearer token required for all tesla commands!"
  usage
fi

if [ $os_name != "Darwin" ]; then
  jq_bin=/usr/bin/jq
fi


# the commands
case $1 in
  id)
    execute "vehicles"
  ;;
  state)
    execute "vehicles/$tesla_id/data_request/vehicle_state"
  ;;
  wakeup)
    wakeup
  ;;
  charge)
    execute "vehicles/$tesla_id/data_request/charge_state"
  ;;
  climate)
    execute "vehicles/$tesla_id/data_request/climate_state"
  ;;
  drive)
    execute "vehicles/$tesla_id/data_request/drive_state"
  ;;
  honk)
    execute "vehicles/$tesla_id/command/honk_horn" "POST" "on=true"
  ;;
  start)
    # yuk, this needs tesla password! This is a handy command if phone ran out of
    # battery or misplaced or worse lost and you don't have keycard. This command 
    # allows us to unlock car, and drive w/ out keycard or app
    tesla_passwd=$2
    if [ -z $tesla_passwd ] ; then
      echo "[ERROR] start command requires your tesla account password!"
      exit
    fi
    execute "vehicles/$tesla_id/command/remote_start_drive" "POST" "password=$tesla_passwd"
  ;;
  update)
    # software update, requires # seconds arg
    secs=$2
    if [ -z $secs ] ; then
      echo "[ERROR] software update command requires number seconds delay before updates start"
      exit
    fi
    execute "vehicles/$tesla_id/command/schedule_software_update" "POST" "offset_sec=$secs"
  ;;

  sentry)
    sc=$2
    if [ -z $sc ] ; then
      echo "[ERROR] sentry command requires argument 'true' or 'false'"
      exit
    fi
    case "$sc" in
      true|false)
      execute "vehicles/$tesla_id/command/set_sentry_mode" "POST" "on=$sc"
      ;;
      *)
      echo "[ERROR] sentry argument '$sc' must be 'true' or 'false'"
      exit
      ;;
    esac
  ;;
  lock)
    execute "vehicles/$tesla_id/command/door_lock" "POST" "on=true"
  ;;
  unlock)
    execute "vehicles/$tesla_id/command/door_unlock" "POST" "on=true"
  ;;
  location) "$@"
  ;;
  log)
    execute "diagnostics"
  ;;
  light)
    execute "vehicles/$tesla_id/command/flash_lights" "POST" "on=true"
  ;;
  *) usage
  ;;
esac

