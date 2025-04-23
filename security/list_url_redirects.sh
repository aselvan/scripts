#!/usr/bin/env bash
#
# list_url_redirects.sh --- Recursively list redirects on a URL
#
#
# Author:  Arul Selvan
# Created: Apr 22, 2025
#
# Version History:
#   Apr 23,  2025 --- Orginal version
#

# version format YY.MM.DD
version=25.04.23
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Recursively list redirects on a URL"
my_dirname=`dirname $0`
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="u:vh?"

url=""
redirect_list=()

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -u <url>   ---> URL to check for all recursive redirects
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: 
  $my_name -u "https://blly.ink/askdoctors"

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
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    u)
      url="$OPTARG"
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
  log.error "Missing arguments. Need URL, see usage below"
  usage
fi

# Use a loop to trace redirects
current_url=$url
while true; do
  # Get the headers and fetch the "Location" value (next redirect)
  next_url=$(curl -s -D - -o /dev/null "$current_url" | awk '/^Location:/ {print $2}' | tr -d '\r')
  
  # Break if there's no "Location" (no more redirects)
  if [[ -z "$next_url" ]]; then
    break
  fi
    
  # Save the next URL into the list
  redirect_list+=("$next_url")
    
  # Update the URL to the next one
  current_url=$next_url
done

# Output all intermediate URLs
order=1
log.stat "Redirect chain order: "
log.stat "  ${order}. ---> $url"
for redirect in "${redirect_list[@]}"; do
  ((order++))
  log.stat "  ${order}. ---> $redirect"
done
