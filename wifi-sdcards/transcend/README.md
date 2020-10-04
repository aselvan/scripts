# SSH access to Wifi SD card

## Description
The following are steps to get full root and ssh access to transend Wifi SD card 
to automate copying of files to/from the card wirelessly while the card is in a 
device like digital camera or any other devices that use SD card for storage. It 
is assumed that the user is familiar with some knowledge of Linux scripts and 
commands. It is also assumed that the user is going to use a Linux or a Mac host 
to interact with the card.

## Disclaimer
These scripts comes without warranty of any kind what so ever. You are free to use it at 
your own risk. I assume no liability for the accuracy, correctness, completeness, or 
usefulness of any information provided by this scripts nor for any sort of damages 
using these scripts may cause.

## Steps
1. First, use the transend tools (andriod app or ios app) to configure your card 
   to connect to your home wifi network. You can also configure via web 
   interface. For web interface, once the card is powered, by default it 
   provides a hotspot with ssid "WIFISD" which you can connect to using default 
   password '12345678' and use browser to configure. Once connected, change 
   admin user, wifi passwd, ssid etc from the default. 

2. edit the autorun.sh file and set debug=1, this will run telnetd so you can 
   telnet to the card to complete the rest of the steps. Once you setup the sshd 
   in following steps, set debug back to 0 so you don't have a wide open access 
   to your card exposed :)

3. edit the access.sh file and change "trusted_network_home,work,other" variables to 
   match yours
   ```
   trusted_network_home="your_routers_ssid::your_router_mac"
   ```
   example: trusted_network="yourrouterssid:ff:ff:ff:ff:ff:ff"
 
4. insert your SD card in your computer and create a `custom/` directory on the SD card 
   and copy the entire content of this directory to the SD card's custom directory. Copy
   the `autorun.sh` to the root directory as well along side the `custom/` directory

5. remove the card and reinsert it into your computer.

6. now you should be able to telnet to your card from your linux or macOS i.e. telnet <your_card_ip>

   In the examples shown below `192.168.1.123` is my WifiSD card
 
 ```
   arul@cheetah:~$ telnet 192.168.1.123
   Trying 192.168.1.123...
   Connected to 192.168.1.123.
   Escape character is '^]'.
   ls
   bin             home            lost+found      sbin            usr
   config_value    init            mnt             sys             var
   dev             lib             proc            tmp             www
   etc             linuxrc         root            ts_version.inc
```

7. Once you are logged in via telnet as shown at #6 above, you need to create your 
   dropbear hostkeys and copy them to your computer to be included in `/custom` directory 
   on SDcard as shown below. I have included two dummy files you need to replace them 
   with the ones you created. 
   
```
   dropbearkey -t rsa -f /tmp/dropbear_rsa_host_key
   dropbearkey -t dss -f /tmp/dropbear_dss_host_key
```
  Now, scp these files to your destop somewhere like /tmp
   
```
   scp /tmp/dropbear_* yourusername@yourdesktop:/tmp/.
```
   
   Note: the keys are created above in your telnet session so you can copy them to your sdcard's 
   `/custom` directory by scp'ing these files to your mac or linux desktop then place them 
   in the SD card's`custom/` folder.
   
8. Create (or copy if you already have a public key) in your desktop to 
   the /custom directory. 
   
   Note: I have a dummy authorized_keys file that you need to replace.

```
   ssh-keygen -t dsa
   cp ~/.ssh/id_dsa.pub custom/authorized_keys
```

9. Once you update the key files in custom/ directory in the SD card, unplug your card and 
   plug it back into your device (computer or camera) one last time.

10. Once the card boots, you now can now ssh into your card (or scp files), or setup automated  
   scripts to copy files to/from card to your desktop, and pretty much do everything you 
   can do with ssh.
   
   For example, below scp command copies all image files from camera (note: the card is in 
   my digital camera) to my desktop. As you can see, you can setup a cronjob on your 
   desktop to copy anything from any device like camera or whatever to desktop in an 
   automated way.
   
   Note: the SD card root is available at `/mnt/sd` and `192.168.1.123` is my SD cards IP.

```
   arul@cheetah:/tmp$ scp -r root@192.168.1.123:/mnt/sd/DCIM/* .
   DSCN0254.JPG                                100%  836KB 278.8KB/s   00:03  
```

## Tools 
   This is where I got the 2 binaries from but they are already in the custom/ directory. 
   - arm5l busybox: http://busybox.net/downloads/binaries/latest/
   - arm5l dropbear: http://landley.net/aboriginal/about.html

## Credit 
   - https://www.pitt-pladdy.com/blog/_20140202-083815_0000_Transcend_Wi-Fi_SD_Hacks_CF_adaptor_telnet_custom_upload_/
   - http://haxit.blogspot.ch/2013/08/hacking-transcend-wifi-sd-cards.html
