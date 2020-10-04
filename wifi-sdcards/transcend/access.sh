# 
# access.sh - starts ssh service once we get connected to our trusted wireless network
#
# Note: need to change the variable "trusted_network" to match your network.
#
# Author:  Arul Selvan
# Version: May 2, 2014
# 
# CREDIT: this script is based on information and code shared from original authors below.
# https://www.pitt-pladdy.com/blog/_20140202-083815_0000_Transcend_Wi-Fi_SD_Hacks_CF_adaptor_telnet_custom_upload_/
# http://haxit.blogspot.ch/2013/08/hacking-transcend-wifi-sd-cards.html
# 
# DISCLAIMER: Use it at your own risk. I am not responsible for any loss or damage to your property.

# TODO: modify the variable below to your own routers ssid/mac to prevent this 
# card to not enable sshd when it is powered anywhere.
###################### REPLACE THESE 3 WITH YOUR OWN ROUTERs info #####################
trusted_network_home="your_router_ssid:your_router_mac"
trusted_network_work="your_router_ssid:your_router_mac"
trusted_network_other="your_router_ssid:your_router_mac"

log_file="/tmp/access.sh.log"
mtd_path="/mnt/mtd"

# kill dropbear
killaccessdaemons() {
    if [ -f /var/run/dropbear.pid ]; then
        kill `cat /var/run/dropbear.pid`
        rm /var/run/dropbear.pid
    fi
}

# start dropbear for sshd service
startaccessdaemons() {
    if [ ! -f /var/run/dropbear.pid ] || [ ! -d /proc/`cat /var/run/dropbear.pid` ]; then
        dropbear -s -r /etc/dropbear/dropbear_rsa_host_key -d /etc/dropbear/dropbear_dss_host_key
        echo "started dropbear, PID=`cat /var/run/dropbear.pid`" >> $log_file
    fi
}

echo "[INFO] `date`: Starting access.sh run ..." >$log_file

# collect info about our surroundings
apssid=`busybox-armv5l head -n 1 /tmp/iwconfig_maln0.txt | busybox-armv5l sed 's/^.*ESSID:"\([^"]\+\)".*$/\1/'`
ping -c 1 $router >/dev/null 2>&1
routerMAC=`busybox-armv5l arp -n $router | busybox-armv5l awk '{print $4}'`
#current_network="$apssid:$router:$routerMAC"
current_network="$apssid:$routerMAC"
my_ip=`/sbin/ifconfig mlan0|grep inet|/sbin/busybox-armv5l awk '{print $2}'`

# the ping above seem to hang forever, kill it here
kill `ps |grep ping|grep -v grep|busybox-armv5l awk '{print $1}'` 

# debug info
echo "dhcp command    = $1" >>$log_file
echo "router          = $router" >> $log_file
echo "apssid          = $apssid" >> $log_file
echo "routerMAC       = $routerMAC" >> $log_file
echo "current_network = $current_network" >> $log_file
echo "Assigned IP     = $my_ip" >> $log_file
echo "" >> $log_file
sync

# check the situation and act accordingly
case "$1" in
    deconfig)
        killaccessdaemons
    ;;
    bound)
        case $current_network in
            $trusted_network_home )
                # trusted network - run sshd (dropbear)
                echo "Trusting $trusted_network_home, starting sshd service..." >> $log_file
                startaccessdaemons
            ;;
            $trusted_network_work )
                # trusted network - run sshd (dropbear)
                echo "Trusting $trusted_network_work, starting sshd service..." >> $log_file
                startaccessdaemons
            ;;
            $trusted_network_other )
                # trusted network - run sshd (dropbear)
                echo "Trusting $trusted_network_other, starting sshd service..." >> $log_file
                startaccessdaemons
            ;;
            *)
                # unknown 
                echo "$current_network is NOT trusted, doing nothing." >> $log_file                
                killaccessdaemons
            ;;
        esac
    ;;
    renew)
        # do nothing - no change
    ;;
esac

# copy the log file to mtd_path which can survive reboot and the next boot
# will be able copy to SD path in autorun.sh
cp $log_file $mtd_path/.
echo "[INFO] `date`: access.sh completed." >>$log_file
sync
