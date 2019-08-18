#!/bin/bash

#
# Description:
# Shell script to force a reboot on Vonage v-portal VDV21 via the 
# web interface. NOTE: this is tested on the firmware 2.8.1-2.2.8 up to 
# 3.2.9-0.6.1 no guarantee if this will work on later firmwares. 
#
# Method:
# Basically login the web interface, invoke a change to the dhcp page 
# with a change for Ending local address field, randomly generated to 
# a number between 10 and 50. We need to make a change otherwise the
# reboot is not initiated.
#
# Author:  Arul Selvan
# Version: Jul 17, 2010
# 
# DISCLAIMER: Use this script at your own risk. I am not responsible for any damage 
# of any sort to your router or anything else as a result of using this script.
#

# TODO: change it to some existing directory, just used to create log files
reboot_home=/root/vonage_reboot

# TODO: replace 192.168.1.100 with your vonage device IP
loginUrl="http://192.168.1.100:8080/goform/login"
indexUrl="http://192.168.1.100:8080/index.html"
dhcpUrl="http://192.168.1.100:8080/goform/dhcp"
routerUser="router"

# TODO: change it to your router password
routerPassword="your_vonage_router_password_here"

loginPostData="loginUsername=${routerUser}&loginPassword=${routerPassword}&x=31&y=14"
#wgetArgs="--output-file=vportal.log -q -O vportal_html.log --no-http-keep-alive"
wgetArgs="--output-file=vportal.log -q -O vportal_html.log"

# TODO: change it to some path where you can write to.
runLog="/var/www/vportalReboot.html"
loginCheck="Please enter your"
sleepSecs=300
RANDOM=`date '+%s'`
endAddress=
dhcpPostData=
maxLoop=3
loginOnly=0

init() {
	cd $reboot_home || exit
	echo "<html><h1>Vonage v-portal reboot log</h1><br><pre>" > $runLog
	echo "Running: $0 " >> $runLog
	echo "Start Time: `date`" >> $runLog
	echo "Login URL: $loginUrl" >> $runLog
	echo "DHCP URL: $dhcpUrl" >> $runLog

	# seed random with date
	endAddress=$[ ($RANDOM % 40) +11 ]
	if [ $endAddress -lt 10 -o $endAddress -gt 200 ]; then
		echo "endAddress is has unexpected value: $endAddress, aborting execution.</pre></html>" >> $runLog
		exit
	fi
	dhcpPostData="DhcpServerEnable=0x1000&LocalIpAddressIP0=192&LocalIpAddressIP1=168&LocalIpAddressIP2=15&LocalIpAddressIP3=1&SubnetMask0=255&SubnetMask1=255&SubnetMask2=255&SubnetMask3=0&StartingLocalAddressIP3=2&EndingLocalAddressIP3=${endAddress}&LeaseTimeDays=7&LeaseTimeHours=0&LeaseTimeMins=0&apply.x=30&apply.y=1"

	# save the parameters we are using to invoke reboot for review
	echo "Ending Local Address used: $endAddress" >> $runLog
	#echo "DHCP url post data: $dhcpPostData" >> $runLog
}

check_status() {
	# sometimes (no clue why/when) login or dhcp fails, check status here
	# NOTE: the html output from v-portal will contain string $loginCheck 
	# if the login attempt failed
	/bin/cat $reboot_home/vportal_html.log | /bin/grep -i "$loginCheck" > /dev/null 2>&1
	rc=$?
	return $rc
}

# login and create a session
do_login() {
	/usr/bin/wget --save-cookies cookies.txt --keep-session-cookies --post-data "$loginPostData" $wgetArgs $loginUrl >>$runLog 2>&1
	rc=$?
	if [ $rc -ne 0 ]; then
		echo "    Login failed, aborting execution </pre></html>" >> $runLog
		exit
	fi
}

# change a the ending address in DHCP range to force a reboot
do_dhcp() {
	/usr/bin/wget --load-cookies cookies.txt --post-data "$dhcpPostData" $wgetArgs $dhcpUrl >>$runLog 2>&1
	rc=$?
	if [ $rc -ne 0 ]; then
		echo "    DHCP change and reboot failed! </pre></html>" >> $runLog
		exit
	fi
}

usage() {
   echo "Usage: $0 [--login]"
   echo "   --login --> only do login and exit"
   exit
}

# -----------------  Start of main ----------------

# parse commandline args
while [ "$1" ] 
do
	if [ "$1" = "--login" ]; then
		shift 1
		loginOnly=1
	elif [ "$1" = "--help" ]; then
		usage
	else
		usage
	fi
done

# setup and initialize stuff
init

# login attempt. Need the retry mechanism because of the 
# webserver interface on vonage device is so flaky and doesn't 
# work reliably
echo "Attempting to login and do DCHP change request for $maxLoop times." >> $runLog
i=0
echo "Invoking login at: `date`" >> $runLog
for ((i=0; i<$maxLoop; i++)) do
	do_login
	check_status
	rc=$?
	if [ $rc -ne 0 ]; then
		# success (note: 0 means login was not succcessful)
		echo "    Login success at attempt# $i ">> $runLog
		break;
	fi
done


if [ $loginOnly -eq 1 ]; then
	echo "Requested just login attempt, so exiting now  </pre><hr></html>" >> $runLog
	echo "The following is the output from v-portal after $i times login attempt(s)" >> $runLog
	cat vportal_html.log >> $runLog
	echo "" >> $runLog
	exit
fi

if [ $i -eq $maxLoop ]; then
	echo "Login failed even after $i attempts, attempting DHCP, just for the heck" >> $runLog
fi

# dhcp change attempt. Need the retry mechanism because of the 
# webserver interface on vonage device is so flaky and doesn't 
# work reliably
echo "Invoking DHCP change request at: `date`" >> $runLog
for ((i=0; i<$maxLoop; i++)) do
	do_dhcp
	check_status
	rc=$?
	if [ $rc -ne 0 ]; then
		# success (note: 0 means dhcp was not succcessful)
		echo "    DHCP change success at attempt# $i ">> $runLog
		break;
	fi
done

if [ $i -lt $maxLoop ]; then
	echo "DHCP change request completed at: `date`" >> $runLog
	echo "SUCCESS: V-portal should be rebooting now ...  </pre><hr></html>" >> $runLog
else
	echo "ERROR: DHCP failed even after $i attempts!, giving up </pre><hr></html>" >> $runLog
fi
echo "The following is the output from v-portal for DHCP change request" >> $runLog
cat vportal_html.log >> $runLog
echo "" >> $runLog
