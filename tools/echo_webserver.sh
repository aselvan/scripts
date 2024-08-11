#!/usr/bin/env bash
#
# echo_webserver.sh --- runs a tiny echo echo webserver using netcat
#
#
# Author:  Arul Selvan
# Created: Aug 11, 2024
#
# Version History:
#   Feb 17, 2015 --- Original version from .bashrc converted to this script
#

# version format YY.MM.DD
version=24.08.11
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Tiny echo webserver using netcat"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="e:lvh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

port=8080
string="<html><h3>$my_name --- $my_title</h3><p><b>Enjoy!</b></html>"
string_len=${#string}
response=""
loop=0

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -e <string> ---> string to echo [Default: $string]
  -p <port>   ---> port to listen to [Default: $port]
  -l          ---> loops forever [Default: send response to first HTTP GET and exit]
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -e "hello world" -p 8080 -l
  
EOF
  exit 0
}

create_response() {
  # create a echo request
  response=$(cat << EOF 
HTTP/1.1 200 OK\r\n
Content-Type: text/plain\r\n
Content-Length: $string_len\r\n\r\n
$string
EOF
)
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
check_installed nc

# parse commandline options
while getopts $options opt ; do
  case $opt in
    e)
      string="$OPTARG"
      ;;
    p)
      port="$OPTARG"
      ;;
    l)
      loop=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

log.stat "Running echo webserver @$port ... Press Ctrl+C to exit."
create_response

if [ $loop -eq 1 ] ; then
  while true ; do
    echo -e $response | nc -l $port 2>&1 >> $my_logfile
  done
else
    echo -e $response | nc -l $port 2>&1 >> $my_logfile
fi
