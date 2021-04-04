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
macos_unreadable="com.apple.homed.notbackedup.plist|com.apple.homed.plist|com.apple.mail-shared.plist|com.apple.AddressBook.plist"
chrom_plugin_excludes="urlhaus-filter-online.txt"
macos_false_positive="--exclude=EPSON.*FAX.*.gz"
exclude_files=".qcow2|.swf|.ova|.vmdk|.mp3|.mp4|.jpg|.jpeg|.JPG|.MTS|.jar|.pst|.ost|.mov|.pack|$macos_unreadable|$chrom_plugin_excludes"
pua_args="--detect-pua=yes --exclude-pua=PwTool --exclude-pua=NetTool --exclude-pua=P2P --exclude-pua=Tool"

# other variables don't need to be changed
options_list="uhvcp:m:f:l:d:"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
virus_report=/tmp/virus_report.log
changed_files=/tmp/clamscan_files.txt
freshclam_log_file=/tmp/freshclam.log
changed_only=0
days_since=8
max_file_size="128M"
default_linux_scan_path="/"
scan_path="$default_linux_scan_path"
# use this for macOS since starting from catalina lot of OS area is mounted under "/"
# that is not writeable anyway (unless SIP disabled) so dont bother scanning
default_macos_scanpath="/Applications /Library /Users /usr/local"
os_name=`uname -s`
my_host=`hostname`
urlhaus_sig_file="urlhaus.ndb"
urlhaus_sig_url="https://urlhaus.abuse.ch/downloads"
clamscan_path_mac="/usr/local/bin"
clamscan_path_linux="/usr/bin"
clamscan_bin="$clamscan_path_mac/clamscan"
freshclam_bin="$clamscan_path_mac/freshclam"
sha256sum_bin="/usr/local/bin/sha256sum"
single_file=""
clamav_lib_path=""
update_signature_only=0
# mail variables
subject="ClamAv virus scan report [Host: $my_host]"
mail_to=""
exit_code=0
verbose_opt="--quiet"
clamscan_opts="-r -i -o --max-filesize=$max_file_size $pua_args --log=$virus_report --exclude-dir=\"$exclude_dirs\" --exclude=\"$exclude_files\" $macos_false_positive --bytecode-unsigned --bytecode-timeout=120000"

usage() {
  echo "Usage: $my_name [options]"
  echo "    -p <paths_to_scan> list of directories to scan in quotes. note: the default is '/'"
  echo "    -c scan only changed files since the last $days_since days"
  echo "    -d <days> number of days to check for changed files. default: $days_since days"
  echo "    -f <single_file> scan a single file and exit"
  echo "    -m <email_address> enable email and send scan results"
  echo "    -l <log_file_path> log file path, default=$log_file"
  echo "    -u update signature only (i.e. freshclam, urlhouse filter, pua setup etc) don't scan"
  echo "    -v enable verbose mode"
  exit
}

scan_single_file() {
  echo "[INFO] scanning file: '$single_file' ... " | tee -a $log_file
  if [ -f "$single_file" ]; then
    $clamscan_bin $verbose_opt $clamscan_opts "$single_file" >> $log_file
    exit_code=$?
    echo "[INFO] scan results..." | tee -a $log_file
    cat $virus_report
  else
    echo "[ERROR] file '$single_file' does not exist!" | tee -a $log_file
  fi
}

# determine the clamav lib path (located at different place on MacOS and Linux)
get_clamav_path() {
  #clamav_home="$(dirname `which clamscan`)/$(readlink `which clamscan`|xargs -0 dirname|xargs -0 dirname)"
  #the above doesn't work under cron, so hardcoding clamscan path but still dynamically determine exact path.

  if [ $os_name = "Darwin" ]; then
    scan_path=$default_macos_scanpath
    clamscan_bin="$clamscan_path_mac/clamscan"
    clamav_lib_path="$(dirname $clamscan_bin)/$(readlink $clamscan_bin|xargs -0 dirname|xargs -0 dirname)/share/clamav/"
    sha256sum_bin="/usr/local/bin/sha256sum"
  else
    clamscan_bin="$clamscan_path_linux/clamscan"
    freshclam_bin="$clamscan_path_linux/freshclam"
    clamav_lib_path=/var/lib/clamav
    sha256sum_bin="/usr/bin/sha256sum"
  fi
}

# get the urlhaus clamv signature to scan for virus website, compromised hosts etc.
get_urlhaus_sig() {
  if [ -f $urlhaus_sig_file ]; then
    rm -f $urlhaus_sig_file
  fi

  echo "[INFO] downloading $urlhaus_sig_url/{$urlhaus_sig_file,$urlhaus_sig_file.sha256} " >> $log_file
  # download the urlhaus clamv database and sha256sum of the database
  # note: urlhaus creates these 2 files every minute so we have to get both database
  #       and sha256sum files at one shot otherwise, they will be mismatched.
  curl -s -O "$urlhaus_sig_url/{$urlhaus_sig_file,$urlhaus_sig_file.sha256}"
  if [ $? -ne 0 ]; then
    echo "[ERROR] failed to download urlhaus signature file '$urlhaus_sig_file'" >> $log_file
    exit_code=11
    return
  fi

  # check if the sha256sum matches
  echo "[INFO] matching sha256sum: `cat $urlhaus_sig_file.sha256` $urlhaus_sig_file|$sha256sum_bin -c" >> $log_file  
  echo "`cat $urlhaus_sig_file.sha256` $urlhaus_sig_file" | $sha256sum_bin -c >> $log_file 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] MD5 sum does not match for '$urlhaus_sig_file', skiping urlhaus signature..." >> $log_file
    exit_code=12
    return
  fi
  
  # finally scan it before adding to clamscan lib
  echo "[INFO] sha256sum matched, scanning $urlhaus_sig_file " >> $log_file    
  $clamscan_bin $urlhaus_sig_file >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] scan failed for $urlhaus_sig_file, so ignoring the file" >> $log_file
    exit_code=13
    return
  fi
 
  # all checked out, move file to clamav lib
  echo "[INFO] updating urlhaus signature file '$urlhaus_sig_file' in clamav lib ($clamav_lib_path)" >> $log_file
  mv $urlhaus_sig_file $clamav_lib_path/.
}

setup_pua() {
  #
  # ensure the PUA override file is there (it will be gone when clamscan is updated, so always write one)
  # CAUTION: ignoring these are not good but too much of noise/false positives forced me to add these!
  #
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
PUA.Win.Tool.Packed-176
EOF
  chmod a+rw $clamav_lib_path/local.ign2
  echo "[INFO] content of $clamav_lib_path/local.ign2 " >> $log_file
  cat $clamav_lib_path/local.ign2 >> $log_file
}

update_all() {
  # do a freshclam first
  echo "[INFO] Get latest virus signatures..." >> $log_file
  if [ -f $freshclam_log_file ] ; then
    rm -f $freshclam_log_file
  fi

  # print current version
  echo "[INFO] current sig version: `$freshclam_bin -V`" >> $log_file

  # update the sigs
  $freshclam_bin -l $freshclam_log_file >> $log_file 2>&1
  exit_code=$?

  # print the updated version
  echo "[INFO] updated sig version: `$freshclam_bin -V`" >> $log_file

  # update urlhaus signature
  get_urlhaus_sig

  # setup the PUA overide
  setup_pua
}

# ---------------------------- main --------------------------------

# first, clamav path for target OS, write log header etc.
get_clamav_path
if [ -f  $virus_report ]; then
  rm -f $virus_report
fi

# now, parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    p)
      scan_path="$OPTARG"
      ;;
    c)
      changed_only=1
      ;;
    m)
      mail_to=$OPTARG
      ;;
    v)
      verbose_opt="-v"
      ;;
    f)
      single_file=$OPTARG
      scan_path=$OPTARG
      ;;
    l)
      log_file=$OPTARG
      ;;
    d)
      days_since=$OPTARG
      ;;
    u)
      echo "[INFO] updating virus definitions ..." > $log_file
      update_all
      exit $exit_code
      ;;
    h)
      usage
      ;;
  esac
done

echo "[INFO] -------------------- VIRUS SCAN log starting --------------------" > $log_file
echo "" >> $log_file
echo "[INFO] Scan start:   `date`" >> $log_file
echo "[INFO] Scan host:    $my_host" >> $log_file
if [ ! -z $mail_to ] ; then
  echo "[INFO] Email report: Yes" >> $log_file
fi
echo "[INFO] Scan path:    $scan_path " >> $log_file
echo "[INFO] Scan bin:     $clamscan_bin " >> $log_file
echo "[INFO] Scan lib:     $clamav_lib_path " >> $log_file
echo "[INFO] Scan options: $verbose_opt $clamscan_opts " >> $log_file

# special case: single file scan; need to scan fast, so not updating signature
if [ ! -z "$single_file" ] ; then
  scan_single_file
  exit $exit_code
fi

# update everything, sig database (freshclam), pua, and urlhaus filter etc.
update_all

# finally, run the scan
if [ $changed_only -eq 1 ] ; then
  if [ -f $changed_files ] ; then
    rm -f $changed_files
  fi
  touch $changed_files
  # get a report of changed files in the last $days_since days
  for dir in $scan_path ; do
    find $dir -type f -mtime -$days_since -exec echo {} \; >> $changed_files
  done
  echo "[INFO] Full command: $clamscan_bin $verbose_opt $clamscan_opts -f $changed_files" >> $log_file  
  echo "[INFO] Scanning changed files in the last $days_since day(s) under '$scan_path'" >> $log_file
  $clamscan_bin $verbose_opt $clamscan_opts -f $changed_files >> $log_file 2>&1
  exit_code=$?
else
  echo "[INFO] Full command: $clamscan_bin $verbose_opt $clamscan_opts $scan_path" >> $log_file
  echo "[INFO] Scanning ALL files under: $scan_path" >> $log_file
  $clamscan_bin $verbose_opt $clamscan_opts $scan_path >> $log_file 2>&1
  exit_code=$?
fi
echo "" >> $log_file

echo "[INFO] Scan end for $scan_path: `date`" >> $log_file
echo "[INFO] return code: $exit_code" >> $log_file
echo "[INFO] Following is virus report for: $scan_path" >> $log_file
echo "" >> $log_file
cat $virus_report >> $log_file
echo "" >> $log_file
echo "[INFO] -------------------- VIRUS SCAN log end --------------------" >> $log_file


# send e-mail if address provided.
if [ ! -z $mail_to ] ; then
  # clamscan return (0: no virus; 1: virus found 2: some errors occured)
  case $exit_code in
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

  echo "[INFO] Scan complete w/ status $exit_code; Results are e-mailed" |tee -a $log_file
  cat $log_file | mail -s "$subject" $mail_to >> $log_file 2>&1
fi

# exit w/ clamscan status for calling scripts
exit $exit_code
