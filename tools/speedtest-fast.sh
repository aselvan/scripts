#!/usr/bin/env bash
#
# speedtest-fast.sh --- Measure bandwidth using netflix provided fast.com.
#
# This also calculates what is the average of X runs (passed as commandline arg), 
# in addition, also creates a HTML file to be displayed on a website which contains
# the history of speed test runs periodically.
#
# Pre Req: needs netflix's fast commandline impl ex: snap install fast [on ubuntu]
#
# Author:  Arul Selvan
# Version History: 
#   Oct 3, 2021  --- Initial version
#   Feb  4, 2024 --- Added functionality to create HTML file, changed output format

# version format YY.MM.DD
version=24.02.04
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Measure bandwidth using netflix provided fast.com"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# commandline options
options_list="e:n:s:r:d:wvh?"

# For HTML file content (change as needed)
title="selvans.net speed test results"
desc="This file contains selvans.net speed test measured by netflix provided fast.com tool"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"

# location of www path, speedtest history file etc.
need_html=0
home_dir=/root/speed_test
www_root=/var/www
html_file=$home_dir/speed_test.html
std_header=$www_root/std_header.html
std_footer=/var/www/std_footer.html

fast_outfile="/tmp/$(echo $my_name|cut -d. -f1)_fast.log"
log_file=$my_logfile
log_file_reverse="/tmp/$(echo $my_name|cut -d. -f1)_reverse.log"
line_count=1
total=0
average=0
dl=""
low_speed=50 # anything below 50Mbit considered low speed
nrun=18
retry_count=1
retry_wait=60

usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -e <email>  ---> email address to send results
  -n <number> ---> number of last runs to calculate average [default: $nrun]
  -s <number> ---> speed in mbit below this number is assumed low speed [default: $low_speed]
  -r <number> ---> number of attempts in case fast.com is not responding [default: $retry_count]
  -d <number> ---> number of seconds to delay/wait between attempts [default: $retry_wait]
  -w          ---> writes HTML file ($html_file) in addition for web server display.

  example: $my_name -r3 -e foo@bar.com

EOF
  exit 0
}

do_speedtest() {
  local result=0
  # run the test
  log.debug "running fast ... "
  fast  > $fast_outfile 2>&1
  if [ $? -ne 0 ] ; then
    log.error "non-zero exit running fast, bailing out..."
    exit 1
  fi

  log.debug "parsing results ..."
  # fast (go implementation by ddooo) writes a ticker with spinning graphic on console
  # we capture that to a file and use awk to get the last line which is the total download speed
  dl=$(cat $fast_outfile|awk -F'>' '{ print $2;}'|awk '{print $1;}')
}

write_html() {
  # calculate average for the last nrun 
  log.stat "calculate average for last $nrun runs..."
  tac $log_file > $log_file_reverse
  while IFS= read -r line ; do
	  ((line_count++))
    if [ $line_count -ge $nrun ]; then
		  break
	  fi
	  dl_avg=$(echo $line|awk '{print $6}')
	  total=$(echo "$total + $dl_avg"|/usr/bin/bc)
  done < $log_file_reverse
  average=$(echo "$total / $nrun"|/usr/bin/bc)

  # prepare the HTML file for website
  log.stat "creating HTML file ($html_file) ..."
  cat $std_header| sed -e "$sed_st"  > $html_file
  echo "<body><pre>" >> $html_file
  echo "<h3>$my_version --- bandwidth test measured by netflix provided fast.com </h3>" >> $html_file
  echo "<b>Current speed:</b> $dl Mbps <br>" >> $html_file
  echo "<b>Average of last $nrun runs:</b> $average Mbps<br><br>" >>$html_file
  tac $log_file  >> $html_file
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

# ------ main -------------
# process commandline
while getopts "$options_list" opt; do
  case $opt in
    e)
      email_address=$OPTARG
      ;;
    n)
      nrun=$OPTARG
      ;;
    s)
      low_speed=$OPTARG
      ;;
    r)
      retry_count=$OPTARG
      ;;
    d)
      retry_wait=$OPTARG
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

ts=$(date +"%D %H:%M %p")
if [ -f $fast_outfile ] ; then
  rm $fast_outfile
fi

# make sure fast exists
check_installed fast

# reset output to permanant store rather then /tmp/ in the case of html runs
if [ $need_html -ne 0 ] ; then
  log_file=$home_dir/speed_test.txt
fi

# attempt $retry_count times
for (( attempt=0; attempt<$retry_count; attempt++)) {
  log.stat "speed test attempt #$attempt ..."
  do_speedtest
  if [[ -z $dl || "$dl" = "0" ]] ; then
    log.stat "sleeping $retry_wait seconds ..."
    sleep $retry_wait
  else
    break
  fi
}

log.stat "Download speed: $dl Mbps"
speedtest_output="[$ts] measured bandwidth: $dl Mbps (download) ; N/A Mbps (upload) ; N/A ms (ping)"
if [ -z $dl ] ; then
  echo "[$ts] Unexpected output 0 " >> $log_file 
else
	echo $speedtest_output >> $log_file
fi

# create HTML with stats if requested
if [ $need_html -ne 0 ] ; then
  write_html
fi

# finally, mail if we found speed is lower than the low_speed threshold
# first, convert $dl to integer for comparison
dl_int=$( printf "%.0f" $dl )
if [ $dl_int -le $low_speed ] ; then
  log.warn "low speed detected: $dl_int Mbps is < $low_speed Mbps, so sending e-mail ..."
  send_mail 0 
fi
