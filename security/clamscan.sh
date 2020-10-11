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
exclude_files=".swf|.ova|.vmdk|.mp3|.mp4|.jpg|.jpeg|.JPG|.MTS|.jar|.pst|.ost|.mov|.pack|$macos_unreadable"

# other variables don't need to be changed
options_list="hvcp:m:f:l:d:"
my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
virus_report=/tmp/virus_report.log
changed_files=/tmp/clamscan_files.txt
freshclam_log_file=/tmp/freshclam.log
changed_only=0
days_since=8
max_file_size="128M"
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
sha256sum_bin="/usr/local/bin/sha256sum"
single_file=""
clamav_lib_path=""
# mail variables
subject="ClamAv virus scan report [Host: $my_host]"
mail_to=""
exit_code=0
verbose_opt="--quiet"
clamscan_opts="-r -i -o --max-filesize=$max_file_size --detect-pua=yes --log=$virus_report --exclude-dir=$exclude_dirs --exclude=$exclude_files --bytecode-unsigned --bytecode-timeout=120000"

usage() {
  echo "Usage: $my_name [-v] [-f <file>] [-c] [-m <email_address>] [-l <log_file_path>] [-p <paths_to_scan>] [-d <days>] -v"
  echo "    -p <paths_to_scan> list of directories to scan in quotes. note: the default is '/'"
  echo "    -c scan only changed files since the last $days_since days"
  echo "    -d <days> number of days to check for changed files. default: $days_since days"
  echo "    -f <single_file> scan a single file and exit"
  echo "    -m <email_address> enable email and send scan results"
  echo "    -l <log_file_path> log file path, default=$log_file"
  echo "    -v enable verbose mode"
  exit
}

scan_single_file() {
  echo "scanning file: '$single_file' ... " | tee -a $log_file
  if [ -f $single_file ]; then
    $clamscan_bin $verbose_opt $clamscan_opts $single_file | tee -a $log_file
    exit_code=$?
  else
    echo "[ERROR] file '$single_file' does not exist!" | tee -a $log_file
  fi
}

# determine the clamav lib path (located at different place on MacOS and Linux)
get_clamav_path() {
  #clamav_home="$(dirname `which clamscan`)/$(readlink `which clamscan`|xargs -0 dirname|xargs -0 dirname)"
  #the above doesn't work under cron, so hardcoding clamscan path but still dynamically determine exact path.

  if [ $os_name = "Darwin" ]; then
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
  # download the urlhaus clamv sig
  curl -s $urlhaus_sig_url -o $urlhaus_sig_file
  if [ $? -ne 0 ]; then
    echo "[ERROR] failed to download urlhaus signature file '$urlhaus_sig_file'" >> $log_file
    return
  fi

  # check if the shasum matches
  echo "`curl -s $urlhaus_sig_md5_url` $urlhaus_sig_file" | $sha256sum_bin -c >> $log_file 2>&1
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
PUA.Win.Tool.Packed-176
EOF
  chmod a+rw $clamav_lib_path/local.ign2
  echo "[INFO] content of $clamav_lib_path/local.ign2 " >> $log_file
  cat $clamav_lib_path/local.ign2 >> $log_file
}

# --------------- main ----------------------
# parse commandline
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
    h)
      usage
      ;;
  esac
done

# get all clamav path
get_clamav_path

echo "VIRUS SCAN log" > $log_file
echo "---------------" >> $log_file
echo "" >> $log_file
if [ -f  $virus_report ]; then
  rm -f $virus_report
fi
echo "[INFO] Scan start:   `date`" >> $log_file
echo "[INFO] Scan host:    $my_host" >> $log_file
if [ ! -z $mail_to ] ; then
  echo "[INFO] Email report: Yes" >> $log_file
fi
echo "[INFO] Scan path:    $scan_path " >> $log_file
echo "[INFO] Scan bin:     $clamscan_bin " >> $log_file
echo "[INFO] Scan lib:     $clamav_lib_path " >> $log_file
echo "[INFO] Scan options: $verbose_opt $clamscan_opts " >> $log_file


# only if this is for a single scan
if [ ! -z $single_file ] ; then
  scan_single_file
  exit $exit_code
fi

# do a full or partial scan as needed
if [ $changed_only -eq 1 ]; then
  echo "[INFO] Scanning only changed files in the last $days_since days" >> $log_file
else
  echo "[INFO] Scanning all files ..." >> $log_file
fi
echo "" >> $log_file

# do a freshclam first
echo "[INFO] Get latest virus signatures..." >> $log_file
$freshclam_bin -l $freshclam_log_file >> $log_file 2>&1

# update urlhaus signature
get_urlhaus_sig

# setup the PUA overide
setup_pua

# run the scan
if [ $changed_only -eq 1 ] ; then
  if [ -f $changed_files ] ; then
    rm -f $changed_files
  fi
  touch $changed_files
  # get a report of changed files in the last $days_since days
  for dir in $scan_path ; do
    find $dir -type f -mtime -$days_since -exec echo {} \; >> $changed_files
  done
  echo "[INFO] Scanning changed files in the last $days_since day(s) under '$scan_path'" >> $log_file
  $clamscan_bin $verbose_opt $clamscan_opts -f $changed_files >> $log_file 2>&1
  exit_code=$?
else
  echo "[INFO] Scanning ALL files under: $scan_path" >> $log_file
  $clamscan_bin $verbose_opt $clamscan_opts $scan_path >> $log_file 2>&1
  exit_code=$?
fi

echo "[INFO] Scan end for $scan_path: `date`" >> $log_file
echo "[INFO] return code: $exit_code" >> $log_file
echo "[INFO] Following is virus report for: $scan_path" >> $log_file
echo "" >> $log_file
cat $virus_report >> $log_file
echo "[INFO] --- End of virus scan log --- " >> $log_file

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
