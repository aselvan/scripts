#!/usr/bin/env bash
#
#
# clamscan.sh --- wrapper script for clamscan 
#
# This script can be run on cron to scan the files under specified path
# and optionally send mail if one or more files are infected. This will 
# run on both MacOS and Linux assuming clamscan is installed.
#
# NOTE: feel free to modify the below variables in TODO section like scanpath, 
#       excludes_dir, excluded_files, and others to fit your needs.
#
# Author: Arul Selvan
# Version History: 
#   May 28, 2018 --- Original Version.
#   Jan 26, 2024 --- Refactored to use logger, function includes, exclude large files.
#   Feb 11, 2024 --- Added code to write html file optionally.
#

# version format YY.MM.DD
version=24.02.11
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Sample script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="wuhvcp:m:f:l:d:e:x:"

# ensure paths so we don't need to deal with location of tools
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# TODO:
# Customize these to fit your needs (these are specific to my needs), the rest should be generic
exclude_dirs=".Trash|.Trashes|.Spotlight-V100|index.spotlightV3|var|dev|private|xarts|CloudStorage|CrashReporter|views|com.apple.mail|creditexpert|javanetexamples|ice|work|VirtualBoxVMs|android|medical_records|react-tutorial|gdrive|configs|google-backup|raspberrypi|offline-videos|Movies|.svn|.ak"
macos_unreadable="com.apple.homed.notbackedup.plist|com.apple.homed.plist|com.apple.mail-shared.plist|com.apple.AddressBook.plist"
chrom_plugin_excludes="urlhaus-filter-online.txt"
misl_excludes="vc56g_exfat.hc"
macos_false_positive="--exclude=EPSON.*FAX.*.gz"
exclude_files=".qcow2|.swf|.ova|.vmdk|.mp3|.mp4|.jpg|.jpeg|.JPG|.MTS|.jar|.pst|.ost|.mov|.pack|.olm|$macos_unreadable|$chrom_plugin_excludes|$misl_excludes"
pua_args="--detect-pua=yes --exclude-pua=PwTool --exclude-pua=NetTool --exclude-pua=P2P --exclude-pua=Tool"

# TODO: 
# If html report is needed fill in your own values here [default: skip]
need_html=0
www_root=/var/www
std_header=$www_root/std_header.html
std_footer=$www_root/std_footer.html
html_file="/tmp/$(echo $my_name|cut -d. -f1).html"
title="selvans.net virus scan log report"
desc="This page contains the output of clamscan log file"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"

# other variables don't need to be changed
virus_report=/tmp/virus_report.log
changed_files=/tmp/clamscan_files.txt
freshclam_my_logfile=/tmp/freshclam.log
changed_only=0
days_since=8
max_file_size="128M"
default_linux_scan_path="/"
scan_path="$default_linux_scan_path"
# use this for macOS since starting from catalina lot of OS area is mounted under "/"
# that is not writeable anyway (unless SIP disabled) so dont bother scanning
default_macos_scanpath="/Applications /Library /Users /usr/local"
my_host=`hostname`
urlhaus_sig_file="urlhaus.ndb"
urlhaus_sig_url="https://urlhaus.abuse.ch/downloads"
clamscan_bin=`which clamscan`
freshclam_bin=`which freshclam`
sha256sum_bin=`which sha256sum`
single_file=""
clamav_lib_path=""
update_signature_only=0
exit_code=0
verbose_opt="--quiet"
clamscan_opts="-r -i -o --max-filesize=$max_file_size $pua_args --log=$virus_report $macos_false_positive --bytecode-unsigned --bytecode-timeout=120000"

usage() {
cat << EOF
Usage: $my_name [options]
  -p <path>  ---> list of directories path to scan in quotes. note: the default is '/'
  -c         ---> scan only changed files since the last $days_since days
  -d <days>  ---> number of days to check for changed files. default: $days_since days
  -f <file>  ---> scan a single file and exit
  -m <email> ---> enable email and send scan results
  -l <log>   ---> log file path [default: $my_logfile]
  -u         ---> update signature only (i.e. freshclam, urlhouse filter, pua setup etc) don't scan
  -e <list>  ---> pipe delimited list of files, extensions to exclude from scane example: ".mp3|.mp4|myfile"
  -x <dir>   ---> pipe delimited list of directories to exclude from scane example: "Trash|.ssh"
  -w         ---> writes HTML file ($html_file) in addition for web server display.  
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help
  
EOF
  exit 0
}

# optional function to write html file to show on our website for easy review from anywhere
write_html() {
  # prepare the HTML file for website
  log.stat "creating HTML file ($html_file) ..."
  strip_ansi_codes $my_logfile  
  cat $std_header| sed -e "$sed_st"  > $html_file
  echo "<body><pre>" >> $html_file
  echo "<h3>$my_version --- scan report results </h3>" >> $html_file
  echo "<b>Scan Path:</b> $scan_path<br>" >> $html_file
  case $exit_code in 
    0)
      echo "<b>Status:</b><font color=\"blue\"> All clean</font><br>" >> $html_file
      ;;
    1)
      echo "<b>Status:</b><font color=\"red\"> Found one or more virus</font><br>" >> $html_file
      ;;
    2)
      echo "<b>Status:</b><font color=\"red\"> ClamAV failed on scan</font><br>" >> $html_file
      ;;
    *)
      echo "<b>Status:</b>Unknown<br>" >> $html_file
      ;;
  esac
  echo "<b>Status code:</b> $exit_code<br>" >> $html_file
  cat $my_logfile  >> $html_file
  echo "</pre>" >> $html_file
  cat $std_footer >> $html_file
  mv $html_file ${www_root}/.
}

scan_single_file() {
  log.stat "Scanning file: '$single_file' ... "
  if [ -f "$single_file" ]; then
    $clamscan_bin $clamscan_opts "$single_file" >> $my_logfile
    exit_code=$?
    cat $virus_report
  else
    log.error "File '$single_file' does not exist!"
  fi
  log.stat "Total runtime: $(elapsed_time)"
}

# get the urlhaus clamv signature to scan for virus website, compromised hosts etc.
get_urlhaus_sig() {
  if [ -f $urlhaus_sig_file ]; then
    rm -f $urlhaus_sig_file
  fi

  log.stat "Downloading $urlhaus_sig_url/{$urlhaus_sig_file,$urlhaus_sig_file.sha256} "
  # download the urlhaus clamv database and sha256sum of the database
  # note: urlhaus creates these 2 files every minute so we have to get both database
  #       and sha256sum files at one shot otherwise, they will be mismatched.
  curl -s -O "$urlhaus_sig_url/{$urlhaus_sig_file,$urlhaus_sig_file.sha256}"
  if [ $? -ne 0 ]; then
    log.error "Failed to download urlhaus signature file '$urlhaus_sig_file'" >> $my_logfile
    exit_code=11
    return
  fi

  # check if the sha256sum matches
  log.stat "Matching sha256sum: `cat $urlhaus_sig_file.sha256` $urlhaus_sig_file|$sha256sum_bin -c" 
  echo "`cat $urlhaus_sig_file.sha256` $urlhaus_sig_file" | $sha256sum_bin -c >> $my_logfile 2>&1
  if [ $? -ne 0 ] ; then
    log.warn "MD5 sum does not match for '$urlhaus_sig_file', skiping urlhaus signature..."
    exit_code=12
    return
  fi
  
  # finally scan it before adding to clamscan lib
  log.stat "sha256sum matched, scanning $urlhaus_sig_file "
  $clamscan_bin $urlhaus_sig_file >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    log.error "Scan failed for $urlhaus_sig_file, so ignoring the file"
    exit_code=13
    return
  fi
 
  # all checked out, move file to clamav lib
  log.stat "Updating urlhaus signature file '$urlhaus_sig_file' in clamav lib ($clamav_lib_path)"
  mv $urlhaus_sig_file $clamav_lib_path/.
}

setup_pua() {
  #
  # ensure the PUA override file is there (it will be gone when clamscan is updated, so always write one)
  # CAUTION: ignoring these are not good but too much of noise/false positives forced me to add these!
  #
  log.stat "Setting up PUA over-ride entries ..." 
  log.stat "clamav HOME=$clamav_lib_path"
  log.stat "Creating clamav overide file ($clamav_lib_path/local.ign2) ..." 

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
PUA.Win.Exploit.CVE_2012_1461-1
EOF
  chmod a+rw $clamav_lib_path/local.ign2
  log.stat "Content of $clamav_lib_path/local.ign2 "
  cat $clamav_lib_path/local.ign2 >> $my_logfile
}

update_all() {
  # do a freshclam first
  log.stat "Get latest virus signatures..."
  if [ -f $freshclam_my_logfile ] ; then
    rm -f $freshclam_my_logfile
  fi

  # print current version
  log.stat "Current sig version: `$freshclam_bin -V`"

  # update the sigs
  $freshclam_bin -l $freshclam_my_logfile >> $my_logfile 2>&1
  exit_code=$?

  # print the updated version
  log.stat "Updated sig version: `$freshclam_bin -V`"

  # update urlhaus signature
  get_urlhaus_sig

  # setup the PUA overide
  setup_pua

  log.stat "Signature update runtime: $(elapsed_time)"
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

if [ -f  $virus_report ]; then
  rm -f $virus_report
fi

# clamav lib path for PUA overide, urlhaus.ndb database etc
if [ $os_name = "Darwin" ]; then
  # this no longer works
  #clamav_lib_path="$(dirname $clamscan_bin)/$(readlink $clamscan_bin|xargs -0 dirname|xargs -0 dirname)/share/clamav/"
  if [ -d /opt/homebrew ] ; then 
    # new brew location
    clamav_lib_path="/opt/homebrew/var/lib/clamav/"
  else
    # old brew location
    clamav_lib_path="/usr/local/var/lib/clamav/"
  fi
else
  # linux location
  clamav_lib_path="/var/lib/clamav"
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
      email_address=$OPTARG
      ;;
    f)
      single_file=$OPTARG
      scan_path=$OPTARG
      ;;
    l)
      my_logfile=$OPTARG
      ;;
    d)
      days_since=$OPTARG
      ;;
    e)
      exclude_files="$exclude_files|$OPTARG"
      ;;
    x)
      exclude_dirs="$exclude_dirs|$OPTARG"
      ;;
    u)
      log.stat "Updating virus definitions ..."
      update_all
      exit $exit_code
      ;;
    w)
      need_html=1
      ;;
    v)
      verbose_opt="-v"
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# add excludes (file/dir) default plus additional commandline passed to options
clamscan_opts="$verbose_opt $clamscan_opts --exclude-dir=\"$exclude_dirs\" --exclude=\"$exclude_files\""
log.stat "Scan start:   `date`" 
log.stat "Scan host:    $my_host"
if [ ! -z $email_address ] ; then
  log.stat "Email report: Yes"
else
  log.stat "Email report: No"
fi
log.stat "Scan path:    $scan_path "
log.stat "Scan bin:     $clamscan_bin "
log.stat "Scan lib:     $clamav_lib_path "
log.stat "Scan options: $clamscan_opts "

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
  log.stat "Full command: $clamscan_bin $clamscan_opts -f $changed_files"
  log.stat "Scanning changed files in the last $days_since day(s) under '$scan_path'"
  $clamscan_bin $clamscan_opts -f $changed_files >> $my_logfile 2>&1
  exit_code=$?
else
  log.stat "Full command: $clamscan_bin $clamscan_opts $scan_path"
  log.stat "Scanning ALL files under: $scan_path" 
  $clamscan_bin $clamscan_opts $scan_path >> $my_logfile 2>&1
  exit_code=$?
fi
cat $virus_report >> $my_logfile
# clamscan return (0: no virus; 1: virus found 2: some errors occured)
log.stat "Scan completed with exit code: $exit_code"
log.stat "Total runtime: $(elapsed_time)"

# send e-mail if address provided
send_mail "$exit_code"

# create HTML with stats if requested
if [ $need_html -ne 0 ] ; then
  write_html
fi

# exit w/ clamscan status for calling scripts
exit $exit_code
