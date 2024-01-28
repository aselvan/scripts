#!/usr/bin/env bash
#
# jitter_max.sh --- Finds the max average jitter along the hop using mtr.
#
# PreReq: 
#   mtr binary (install w/ 'brew install mtr' on macOS or apt-get install mtr in Linux)
#
# Author : Arul Selvan
# Version History: 
#   Jan 27, 2024 --- Initial version
#
# version format YY.MM.DD
version=24.01.27
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Finds the max average jitter along the hop"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# commandline options
options="s:c:o:vh?"

server="speed.cloudflare.com"
count=30
output_file="/tmp/$(echo $my_name|cut -d. -f1).txt"

usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <host>  ---> server to target to measure the jitter [Default: $server]
  -c <count> ---> number of times to repeat the mtr runs [Default: $count]
  -o <file>  ---> append output to file for monitoring over a period of time [Default: $output_file]
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

  example: $my_name -s $server -c$count
  
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
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      count="${OPTARG}"
      ;;
    s)
      server=${OPTARG}
      ;;
    o)
      output_file="${OPTARG}"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# make sure mtr exists
check_installed mtr

# under macOS mtr requires sudo
if [ $os_name = "Darwin" ] ; then
  check_root
fi

mtr -n -c$count -o "M" -r $server | awk -v ts="$(date +%d-%m-%Y\ %H:%M)" 'NR>2 {if ($NF+0 > max+0) {max=$NF; line=$2}} END {print ts, " ; Hop:",line, "; Avg Max jitter:",max}' >> $output_file
log.stat "Output file: $output_file"
