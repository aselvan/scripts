#!/bin/sh
# find_zmeu.sh: 
# Desc: finds the unique IPs, hosts trying to do look for php vulnerabilities in our apache server
# Author  : Arul
# Version : May 7, 2011
#
# Source info: http://ensourced.wordpress.com/2011/02/25/zmeu-attacks-some-basic-forensic/
#

httpLogFile=/var/log/apache2/access.log
zmeuLogFile=/var/www/zmeuAttackers.html
std_header=/var/www/std_header.html
#ufwRules=/var/lib/ufw/user.rules
ufwRules=/lib/ufw/user.rules

title="selvans.net  zmenu log"
desc="This file contains selvans.net zmenu log"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"

cat $std_header |sed -e "$sed_st" > $zmeuLogFile
echo "<body><h2>IPs/Hosts that does ZmEu attacks/scan</h2><br> <pre>" >> $zmeuLogFile
echo "Run date: `date +"%D"`" >> $zmeuLogFile
echo "Source info: http://ensourced.wordpress.com/2011/02/25/zmeu-attacks-some-basic-forensic/" >> $zmeuLogFile
echo "" >> $zmeuLogFile
echo "IP/Hosts List below (need to add to iptables periodically)" >> $zmeuLogFile
echo "" >> $zmeuLogFile
echo "<table border=\"1\" cellspacing=\"1\" cellpadding=\"3\">" >> $zmeuLogFile
echo "<tr><th>Host</th><th>IP</th><th>In iptables?</th><th>Whois Info</th></tr>" >> $zmeuLogFile
#cat $httpLogFile |grep ZmEu |awk '{print $1;}'|sort|uniq >> $zmeuLogFile
output=$(cat $httpLogFile |grep ZmEu |awk '{print $1;}'|sort|uniq)
for hostName in $output;  do
    # see if the lookup succeeds
    lookup=`host $hostName 2>/dev/null`
    if [ $? -eq 0 ]; then
        hostIp=`echo $lookup|awk '{print $3}'`
        # see it is already blocked
	grep $hostIp $ufwRules >/dev/null 2>&1
        if [ $? -eq 0 ]; then
           blocked=Yes
	else
           blocked=No
        fi
        whoisInfo=`whois $hostIp| egrep -w 'descr:|owner:|e-mail:'`
    else
        hostIp="N/A"
        # see it is already blocked
	grep $hostName $ufwRules >/dev/null 2>&1
        if [ $? -eq 0 ]; then
           blocked=Yes
	else
           blocked=No
        fi
        whoisInfo=`whois $hostName| egrep -w 'descr:|owner:|e-mail:'`
    fi
    echo "<tr><td>$hostName</td><td>$hostIp</td><td>$blocked</td><td>$whoisInfo</td> </tr>" >> $zmeuLogFile
done
echo "</table> </pre></body></html>" >> $zmeuLogFile
