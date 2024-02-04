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
#   Feb  4, 2024 --- Added functionality to create HTML file, changed output format
#
# version format YY.MM.DD
version=24.02.04
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
options="s:c:o:wvh?"

my_ip=`wget -qO- ifconfig.me/ip`
server="speed.cloudflare.com"
count=30
jitter_output="/tmp/$(echo $my_name|cut -d. -f1).txt"

# For HTML file content (change as needed)
need_html=0
title="selvans.net jitter max test results"
desc="This file contains hourly internet jitter max average measured by mtr tool"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"
# location of www path, history location etc.
home_dir=/root/speed_test
www_root=/var/www
html_file=$home_dir/jitter_max.html
std_header=$www_root/std_header.html
std_footer=/var/www/std_footer.html


usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <host>  ---> server to target to measure the jitter [Default: $server]
  -c <count> ---> number of times to repeat the mtr runs [Default: $count]
  -o <file>  ---> append output to file for monitoring over a period of time [Default: $jitter_output]
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
  echo "<h3>$my_version --- max average jitter along source & destination as measured by mtr </h3>" >> $html_file
  echo "<b>Source:</b>      $my_ip<br>" >> $html_file
  echo "<b>Destination:</b> $server <br>" >> $html_file
  echo "<b>Iteration:</b>   $count count<br>" >>$html_file
  tac $jitter_output  >> $html_file
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
      jitter_output="${OPTARG}"
      ;;
    w)
      need_html=1
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

# reset output to permanant store rather then /tmp/ in the case of html runs
if [ $need_html -ne 0 ] ; then
  jitter_output=$home_dir/jitter_max.txt
fi

# run jitter test and determine the router/hop that takes high ave jitter
mtr -n -c$count -o "M" -r $server | awk -v ts="[$(date +'%D %H:%M %p')]" 'NR>2 {if ($NF+0 > max+0) {max=$NF; line=$2}} END {print ts, " Router/Hop:",line, "; Avg Max jitter:",max}' | tee -a $jitter_output

# create HTML file if requested
if [ $need_html -ne 0 ] ; then
  write_html
fi
