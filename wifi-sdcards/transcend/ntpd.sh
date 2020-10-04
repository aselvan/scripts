# kill existing ntp daemon
[ -f /var/run/ntpd.pid ] && kill `cat /var/run/ntpd.pid`
# try start a new ntp daemon
if [ -n "$ntpsrv" ]; then
    ntpcommand="busybox-armv5l ntpd"
    for ntp in $ntpsrv; do
        ntpcommand="$ntpcommand -p $ntp"
    done
    $ntpcommand
else
    busybox-armv5l ntpd -p pool.ntp.org
fi
