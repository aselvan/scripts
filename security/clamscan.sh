#!/bin/bash
#
#
# clamscan.sh --- wrapper script for clamscan 
#
# This script can be run on cron to scan the files under specified path
# and optionally send mail if one or more files are infected. This will 
# run on both MacOS and Linux assuming clamscan is installed.
#
# Author: Arul Selvan
# Version: May 28, 2018
#
# NOTE: feel free to modify the below variables in TODO section like scanpath, 
#       excludes_dir, excluded_files, and others to fit your needs.
#

# TODO: modify these to fit your needs, the rest should be fine

# variables that need to be customized
exclude_dirs="Trash|views|com.apple.mail|creditexpert|javanetexamples|ice|work|VirtualBoxVMs|android|sleepyhead|react-tutorial|.svn"
mojave_unreadable="com.apple.homed.notbackedup.plist|com.apple.homed.plist"
exclude_files=".swf|.ova|.vmdk|.mp3|.mp4|.jpg|.jpeg|.JPG|.MTS|.jar|.pst|.ost|.mov|.pack|$mojave_unreadable"

# other variables don't need to be changed
options_list="aucm:h"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
virus_report=/tmp/virus_report.log
changed_files=/tmp/clamscan_files.txt
changed_only=0
days_since=8
scan_path="/"
os_name=`uname -s`
my_host=`hostname`
urlhaus_sig_file="urlhaus.ndb"
urlhaus_sig_url="https://urlhaus.abuse.ch/downloads/$urlhaus_sig_file"
urlhaus_sig_md5_url="https://urlhaus.abuse.ch/downloads/$urlhaus_sig_file.sha256"
clamscan_path_mac="/usr/local/bin"
clamscan_path_linux="/usr/bin"
clamscan_bin="$clamscan_path_mac/clamscan"
freshclam_bin="$clamscan_path_mac/freshclam"
clamav_lib_path=""
# mail variables
subject="ClamAv virus scan report [Host: $my_host]"
mail_to=""
clamscan_opts="-r -i -o --quiet --max-filesize=64M --detect-pua=yes --log=$virus_report --exclude-dir=$exclude_dirs --exclude=$exclude_files --bytecode-unsigned --bytecode-timeout=120000"

usage() {
  echo "Usage: $my_name [-a] [-u] [-c] [-m <email_address>]"
  echo "    -a scan from root i.e. entire system [default]"
  echo "    -u scan from home i.e. /home or /User depending on MacOS or Linux"
  echo "    -m <email_address> enable email and send scan results"
  exit
}

# determine the clamav lib path (located at different place on MacOS and Linux)
get_clamav_lib_path() {
  #clamav_home="$(dirname `which clamscan`)/$(readlink `which clamscan`|xargs -0 dirname|xargs -0 dirname)"
  #the above doesn't work under cron, so hardcoding clamscan path but still dynamically determine exact path.

  if [ $os_name = "Darwin" ]; then
    clamscan_bin="$clamscan_path_mac/clamscan"
    clamav_lib_path="$(dirname $clamscan_bin)/$(readlink $clamscan_bin|xargs -0 dirname|xargs -0 dirname)/share/clamav/"
  else
    clamscan_bin="$clamscan_path_linux/clamscan"
    freshclam_bin="$clamscan_path_linux/freshclam"
    clamav_lib_path=/var/lib/clamav
  fi
}

# get the urlhaus clamv signature to scan for virus website, compromised hosts etc.
get_urlhaus_sig() {
  if [ -f $urlhaus_sig_file ]; then
    rm -f $urlhaus_sig_file
  fi
  # download the urlhaus clamv sig
  curl -s $urlhaus_sig_url -o $urlhaus_sig_file
  if [ $? -ne 0 ]; then
    echo "[ERROR] failed to download urlhaus signature file '$urlhaus_sig_file'" >> $log_file
    return
  fi

  # check if the shasum matches
  echo "`curl -s $urlhaus_sig_md5_url` $urlhaus_sig_file" | sha256sum -c >> $log_file 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] MD5 sum does not match for '$urlhaus_sig_file', skiping urlhaus signature..." >> $log_file
    return
  fi
  
  # finally scan it before adding to clamscan lib
  $clamscan_bin $urlhaus_sig_file >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] scan failed for $urlhaus_sig_file, so ignoring the file" >> $log_file
    return
  fi
 
  # all checked out, move file to clamav lib
  echo "[INFO] updating urlhaus signature file '$urlhaus_sig_file' in clamav lib ($clamav_lib_path)" >> $log_file
  mv $urlhaus_sig_file $clamav_lib_path/.
}

setup_pua() {
  # ensure the PUA override file is there (it will be gone when clamscan is updated, so always write one)
  echo "[INFO] Setting up PUA over-ride entries ..." >> $log_file
  echo "[INFO] clamav HOME=$clamav_lib_path" >> $log_file
  echo "[INFO] creating clamav overide file ($clamav_lib_path/local.ign2) ..." >> $log_file

  cat <<EOF > $clamav_lib_path/local.ign2
PUA.Pdf.Trojan.EmbeddedJavaScript-1
PUA.Html.Trojan.Agent-37075
PUA.Win.Trojan.Xored-1
PUA.Win.Malware.Speedingupmypc-6718419-0
PUA.Win.Malware.Gamemodding-6726308-0
PUA.Andr.Adware.Dowgin-6888245-0
PUA.Win.Downloader.Aiis-6803892-0
PUA.Win.Packer.Exe-6
PUA.Win.Trojan.Generic-6629273-0
PUA.Win.Packer.Devcpp-1
PUA.Win.Packer.Upx-57
PUA.Html.Exploit.CVE_2014_0322-1
PUA.Win.Packer.Mingwin32V-1
PUA.Win.Packer.MingwGcc-3
PUA.Win.Packer.Devcue-1
PUA.Doc.Packed.EncryptedDoc-6563700-0
PUA.Andr.Trojan.Mobidash-6840972-0
PUA.Win.Tool.Packed-176 FOUND
EOF
  chmod a+rw $clamav_lib_path/local.ign2
  echo "[INFO] content of $clamav_lib_path/local.ign2 " >> $log_file
  cat $clamav_lib_path/local.ign2 >> $log_file
}


# --------------- main ----------------------
while getopts "$options_list" opt ; do
  case $opt in 
    a)
      scan_path="/"
      ;;
    u)
      if [ $os_name = "Darwin" ] ; then    
        scan_path="/Users"
      else
        scan_path="/home"
      fi
      ;;
    c)
      changed_only=1
      ;;
    m)
      mail_to=$OPTARG
      ;;
    h)
      usage
      ;;
  esac
done

# get clamav lib path
get_clamav_lib_path

echo "VIRUS SCAN log" > $log_file
echo "---------------" >> $log_file
echo "" >> $log_file
echo "[INFO] Scan start:   `date`" >> $log_file
echo "[INFO] Scan host:    $my_host" >> $log_file
echo "[INFO] Scan path:    $scan_path " >> $log_file
echo "[INFO] Scan bin:     $clamscan_bin " >> $log_file
echo "[INFO] Scan lib:     $clamav_lib_path " >> $log_file
echo "[INFO] Scan options: $clamscan_opts " >> $log_file

if [ $changed_only -eq 1 ]; then
  echo "[INFO] Scanning only changed files in the last $days_since days" >> $log_file
else
  echo "[INFO] Scanning all files ..." >> $log_file
fi
echo "" >> $log_file

# do a freshclam first
echo "[INFO] Get latest virus signatures..." >> $log_file
$freshclam_bin >> $log_file 2>&1

# update urlhaus signature
get_urlhaus_sig

# setup the PUA overide
setup_pua

# run the scan
rm -rf $virus_report
if [ $changed_only -eq 1 ] ; then
  echo "[INFO] Checking changed files in the last $days_since" >> $log_file
  # get a report of changed files in the last $days_since days
  find $scan_path -type f -mtime -$days_since -exec echo {} \; > $changed_files
  echo "[INFO] Scanning changed files in the last $days_since days under: $scan_path" >> $log_file
  $clamscan_bin $clamscan_opts -f $changed_files >> $log_file 2>&1
  status=$?
else
  echo "[INFO] Scanning ALL files under: $scan_path" >> $log_file
  $clamscan_bin $clamscan_opts $scan_path >> $log_file 2>&1
  status=$?
fi

echo "[INFO] Scan end for $scan_path: `date`" >> $log_file
echo "[INFO] return code: $status" >> $log_file
echo "[INFO] Following is virus report for: $scan_path" >> $log_file
echo "" >> $log_file
cat $virus_report >> $log_file
echo "[INFO] --- End of virus scan log --- " >> $log_file

# send e-mail if address provided.
if [ ! -z $mail_to ] ; then
  # clamscan return (0: no virus; 1: virus found 2: some errors occurec
  case $status in
    0)
	    subject="ClamAV: success [Host: $my_host]"
      ;;
    1)
	    subject="ClamAV: Found one or more virus! [Host: $my_host]"
      ;;
    2)
	    subject="ClamAV: failed on scan! [Host: $my_host]"
      ;;
  esac

  echo "[INFO] Scan complete w/ status $status; Results are e-mailed" |tee -a $log_file
  cat $log_file | mail -s "$subject" $mail_to >> $log_file 2>&1
fi
