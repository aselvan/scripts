#!/usr/bin/env bash
#
# url_speedtest.sh --- Simple wrapper over curl to measure timing.
#
#
# Author:  Arul Selvan
# Created: Jan 4, 2024
#

# version format YY.MM.DD
version=24.01.04
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Simple wrapper over curl to measure timing"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

user_agent="Wget/1.11.4"
curl_opt="-s -L -k -o /dev/null -A '$user_agent'"
curl_metrics="-w '%{time_total} %{size_download} %{time_namelookup} %{time_connect} %{time_pretransfer} %{time_redirect}'"
url=""
all=0

# commandline options
options="u:avh?"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -u <url>  ---> URL to use for measuring speed
  -a        ---> Shows all timinings (total,size,dns,connect,pretrans & redirect) [Default: total]
  -v        ---> enable verbose, otherwise just errors are printed
  -h        ---> print usage/help

example: $my_name -u "http://ipv4.download.thinkbroadband.com/100MB.zip"
  
EOF
  exit 0
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
log.init

# parse commandline options
while getopts $options opt ; do
  case $opt in
    u)
      url="$OPTARG"
      ;;
    a)
      all=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $url ] ; then
  log.error "Required argument 'url' missing! See usage below"
  usage
fi

stats=`curl $curl_opt -w '%{time_total} %{size_download} %{time_namelookup} %{time_connect} %{time_pretransfer} %{time_redirect}' $url`
read -r total size dns connect pretrans redirect <<< $stats

if [ $all -eq 1 ] ; then
  log.stat "  Total:    $total/$(sec2msec $total) (sec/msec)"
  log.stat "  Size:     $size/$(byte2mb $size)  (bytes/MB)"
  log.stat "  DNS:      $dns/$(sec2msec $dns) (sec/msec)"
  log.stat "  Connect:  $connect/$(sec2msec $connect) (sec/msec)"
  log.stat "  Pretrans: $pretrans/$(sec2msec $pretrans) (sec/msec)"
  log.stat "  Redirect: $redirect/$(sec2msec $redirect) (sec/msec)"
else
  log.stat "  Total: $total/$(sec2msec $total) (sec/msec)"
fi
