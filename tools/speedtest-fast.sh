#!/bin/bash
#
# speedtest-fast.sh --- wrapper script for netflix's 'fast' test tool to measure speed.
#
# This also calculates what is the average of X runs (passed as commandline arg), 
# in addition, also creates a HTML file to be displayed on a website which contains
# the history of speed test runs periodically.
#
# Pre Req: needs netflix's fast commandline impl ex: snap install fast [on ubuntu]
#
# Author:  Arul Selvan
# Version: Oct 3, 2021
#

my_name=`basename $0`
run_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="e:n:s:h"

# For HTML file content (change as needed)
title="selvans.net speed test results"
desc="This file contains selvans.net speed test measured by speedtest-cli tool"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"

# location of www path, speedtest history file etc.
home_dir=/root/speed_test
www_root=/var/www
speedtest_out=$home_dir/speed_test.log
log_file=$home_dir/speed_test.txt
log_file_reverse=$home_dir/speed_test_reverse.txt
html_file=$home_dir/speed_test.html
std_header=$www_root/std_header.html
line_count=0
total=0
average=0
speedtest_bin="/snap/bin/fast"

# email details
email_subject="SpeedTest low speed detected"
email_address=""
low_speed=50 # anything below 50Mbit considered low speed
nrun=18
os_name=`uname -s`

usage() {
  echo "Usage: $my_name [options]"
  echo "  -e <email_address> --- email address to send results"
  echo "  -n <number>        --- number of last runs to calculate average [default: $nrun]"
  echo "  -s <number>        --- speed in mbit below this number is assumed low speed [default: $low_speed]"
  exit 0
}

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
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

ts=$(date +"%D %H:%M %p")
echo "[INFO] $my_name starting at [$ts] ... " |/usr/bin/tee $run_logfile
if [ -f $speedtest_out ] ; then
  rm $speedtest_out
fi

if [ ! -x $speedtest_bin ]; then
  echo "[ERROR] required tool $speedtest_bin is missing!" | /usr/bin/tee -a $run_logfile
fi

echo "[INFO] running $speedtest_bin ... " |/usr/bin/tee -a $run_logfile
# run the test
$speedtest_bin  > $speedtest_out 2>&1
if [ $? -ne 0 ] ; then
  echo "[WARN] non-zero exit running '$speedtest_bin', bailing out..." |/usr/bin/tee -a $run_logfile
  exit 1
fi

echo "[INFO] parsing results ... " | /usr/bin/tee -a $run_logfile

# fast (go implementation by ddooo) writes a ticker with spinning graphic on console
# we capture that to a file and use awk to get the last line which is the total download speed
dl=$(cat $speedtest_out|awk -F'>' '{ print $2;}'|awk '{print $1;}')

speedtest_out="[$ts] measured bandwidth: $dl Mbps (download) ; N/A Mbps (upload) ; N/A ms (ping)"
echo "[INFO] $speedtest_out" | /usr/bin/tee -a $run_logfile

if [ -z $dl ] ; then
  echo "[$ts] Unexpected output 0 " >> $log_file 
else
	echo $speedtest_out >> $log_file
fi

# calculate average for the last nrun 
echo "[INFO] calculate average for last $nrun runs..." |/usr/bin/tee -a $run_logfile
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
echo "[INFO] creating HTML file ($html_file) ..." |/usr/bin/tee -a $run_logfile
cat $std_header| sed -e "$sed_st"  > $html_file
echo "<body><pre>" >> $html_file
echo "<h2>Speed Test: Measured with speedtest-cli tool</h2>" >> $html_file
echo "<h3>$speedtest_bin $speedtest_opt</h3>" >> $html_file
echo "<h3>Average of last $nrun runs: $average Mbps</h3>" >>$html_file
tac $log_file  >> $html_file
echo "</pre></body></html>" >> $html_file
mv $html_file ${www_root}/.

# finally, mail if we found speed is lower than the low_speed threshold
# first, convert $dl to integer for comparison
dl_int=$( printf "%.0f" $dl )
if [[ $dl_int -le $low_speed && ! -z $email_address ]] ; then
  echo "[INFO] low speed detected: the speed $dl_int Mbps is < $low_speed Mbps, so sending e-mail ..." | /usr/bin/tee -a $run_logfile
  cat $run_logfile | /usr/bin/mail -s "$email_subject" $email_address
fi
echo "[INFO] all done." |/usr/bin/tee -a $run_logfile

