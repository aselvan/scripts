#!/usr/bin/env bash
#
# packet_loss.sh --- Simple packet loss measure using ping
#
#
# Author : Arul Selvan
# Version History: 
#   Mar 19,  2024 --- Initial version
#
# version format YY.MM.DD
version=24.03.22
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Simple packet loss measure using ping"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# commandline options
options="s:c:o:wtvh?"

server="speed.cloudflare.com"
count=256
protocol="udp"
ping_output="/tmp/$(echo $my_name|cut -d. -f1).txt"
ping_running="/tmp/$(echo $my_name|cut -d. -f1).running"

# For HTML file content (change as needed)
need_html=0
title="selvans.net ping stats"
desc="This file contains periodic packet loss measure using ping"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"
# location of www path, history location etc.
home_dir=/root/speed_test
www_root=/var/www
html_file=$home_dir/packet_loss.html
std_header=$www_root/std_header.html
std_footer=/var/www/std_footer.html


usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <host>  ---> target server to measure packet loss [Default: $server]
  -c <count> ---> number of times to repeat ping run [Default: $count]
  -o <file>  ---> append output to file for monitoring over a period of time [Default: $ping_output]
  -w         ---> writes HTML file ($html_file) in addition for web server display.
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

  example: $my_name -s $server -c$count
  
EOF
  exit 0
}

write_html() {
  # prepare the HTML file for website
  log.debug "creating HTML file ($html_file) ..."
  cat $std_header| sed -e "$sed_st"  > $html_file
  echo "<body><pre>" >> $html_file
  echo "<h3>$my_version --- Simple packet loss measure using ping</h3>" >> $html_file
  tac $ping_output  >> $html_file
  echo "</pre>" >> $html_file
  cat $std_footer >> $html_file
  mv $html_file ${www_root}/.
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
      ping_output="${OPTARG}"
      ;;
    w)
      need_html=1
      ;;
    t)
      protocol="tcp"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# reset output to permanant store rather then /tmp/ in the case of html runs
# also avoid running while already a copy is running.
if [ $need_html -ne 0 ] ; then
  if [ -f $ping_running ] ; then
    log.error "Alreay a copy of $my_name is running... exiting"
    exit 2
  fi
  ping_output=$home_dir/packet_loss.txt
fi

# run ping once to see server is good
ping -q -c1 $server >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ] ; then
  echo "[$(date +'%D %H:%M %p')] ; ERROR: ping $server failed with error code: $rc" | tee -a $ping_output
  exit 1  
fi

# run ping with $count times 
touch $ping_running
result=$(ping -q -c$count $server 2>&1 |grep packets)
if [ ! -z "$result" ] ; then
  echo "[$(date +'%D %H:%M %p')] $result ; target: $server" | tee -a $ping_output
else
  echo "[$(date +'%D %H:%M %p')] ; ERROR: ping $server returned empty output" | tee -a $ping_output
fi
rm -f $ping_running

# create HTML file if requested
if [ $need_html -ne 0 ] ; then
  write_html
fi

