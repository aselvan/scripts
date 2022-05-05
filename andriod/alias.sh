#
# alias.sh --- script to source for handy alias on adb shell
#
# Author:  Arul Selvan
# Version: Sep 2017
#
# Note: see busybox_setup.txt in this directory to setup busybox first
#
export BB_HOME="/data/local/tmp"
export PATH="$PATH:$BB_HOME"

export SD_CARD="/sdcard"
export CAM_DATA="$SD_CARD/DCIM/Camera"
export MY_DATA="$SD_CARD/data"

# misl alias for rooted android to make changes to system area i.e. remount rw
alias system_rw='mount -o remount,rw /system'
alias system_ro='mount -o remount,ro /system'

# others
alias myip='echo -n `wget -qO- ifconfig.me/ip`|xargs echo'
alias ll='ls -l'
alias battery='cat /sys/class/power_supply/battery/capacity'

# note: vi stdin does not work on busybox so manually do vi after decrypting
# supply the encrypted filename arg to dec alias ofcourse
# note: remove -md md5 if you are not using macOS native openssl which uses LibreSSL
# that is defaulting to md5 so other platform version of openssl will fail decrypting
alias dec='openssl enc -d -aes-256-cbc -a -md md5 -in'
