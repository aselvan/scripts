#!/usr/bin/env bash
#
# cleanup_space.sh --- delete files/dir that are older than specified days
#
#
# Author:  Arul Selvan
# Created: Sep 22, 2023
#

# version format YY.MM.DD
version=23.09.22
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
dir_name=`dirname $0`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
log_init=0
options="t:d:f:vh?"
verbose=0
failure=0
green=32
red=31
blue=34

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

html_file=/var/www/cleanup_log.html
std_header=/var/www/std_header.html
std_footer=/var/www/std_footer.html
title="selvans.net common cleanup log"
desc="This file contains selvans.net common files cleanup log"
sed_st="s/__TITLE__/$title/g;s/__DESC__/$desc/g"
dir=""
days=""
ext=""
download_dir="/var/www/download/files"

# cleanup list is list of "path,#days,.ext" array separated by space
cleanup_list=("/var/www/tmp,7," "/var/lib/tripwire/report,7,.html" "/var/lib/tripwire/report,30,.twr" "/var/lib/amavis/virusmails,30," "/var/www/public/share,30," "$download_dir,30,")

usage() {
  cat << EOF

  $my_name --- delete files/dir that are older than specified days

  Usage: $my_name [options]
     -t <title>    ---> Title for html log of cleanup run
     -d <desc>     ---> Description for html log of cleanup run
     -v            ---> verbose mode prints info messages, otherwise just errors are printed
     -h            ---> print usage/help

  example: $my_name -h
  
EOF
  exit 0
}

# -- Log functions ---
log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}
log.stat() {
  log.init
  local msg=$1
  local color=$2
  if [ -z $color ] ; then
    color=$blue
  fi
  echo -e "\e[0;${color}m$msg\e[0m" | tee -a $log_file 
}
log.warn() {
  log.init
  local msg=$1
  echo -e "\e[0;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[0;31m$msg\e[0m" | tee -a $log_file 
}

write_std_readme() {
  cat << EOF > $dir/README.txt
  selvans.net --- file/directory cleanup

  This directory is wiped periodically to avoid log and other files piling up since
  it is not part of system logrotate daemon ... so anything here will be removed after 
  specific time to conserve space.

  Last cleanup run: `date`
EOF
}

write_download_readme() {
  cat << EOF > $dir/README.txt
  selvans.net --- download/temporary storage

  This directory contains files shared between family/friends and is a transient 
  storage area. You can store files here by uploading your it via the following
  upload URL: https://upload.selvans.net 


  DISCLAIMER:
  ----------
  Though this storage area protected w/ basic HTTP authentication, by no means it is 
  secure so do not upload anything that may contain information you may not want to share. 
  I take no responsibility whatsoever on the security of the file and its contents.

  NOTE:
  -----
  This directory is wiped periodically (every 30 days) so anything you upload to this 
  directory via the URL https://upload.selvans.net does not stay here forever.

  Last cleanup run: `date`
EOF
}

do_cleanup() {
  log.stat "Cleaning $dir/*$ext that are older than $days days ..."
  # check if path actually exists
  if [ ! -d $dir ] ; then
    log.error "Skipping invalid/non-existent directory: $dir"
    return
  fi
  log.debug "\tfind $dir -name \*$ext -type f -mtime +$days ! -iname index.php ! -iname index.html -delete"
  find $dir -name \*$ext -type f -mtime +$days ! -iname index.php ! -iname index.html ! -iname README.txt -delete 2>&1 >> $log_file
  # write a readme file
  if [ $dir = "$download_dir" ] ; then
    write_download_readme
  else
    write_std_readme
  fi
  find $dir -type d -empty -delete 2>&1 >> $log_file
}

create_html_log() {
  cat $std_header| sed -e "$sed_st"  > $html_file
  echo "<body><h2>Cleanup Log run</h2><pre>" >> $html_file
  # copy log file content to html file after striping ansi color code
  cat $log_file | sed 's/\x1b\[[0-9;]*m//g'  >> $html_file
  echo "</pre>" >> $html_file

  # write footer (takes care of ending body/html tags
  cat $std_footer >> $html_file
}


# ----------  main --------------
log.init

# parse commandline options
while getopts $options opt ; do
  case $opt in
    t)
      sed_st="s/__TITLE__/$OPTARG/g;s/__DESC__/$desc/g"
      ;;
    d)
      sed_st="s/__TITLE__/$title/g;s/__DESC__/$OPTARG/g"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

for entry in "${cleanup_list[@]}" ; do
  IFS=,
  keyval=($entry)
  dir=${keyval[0]}
  days=${keyval[1]}
  ext=${keyval[2]}
  IFS=$IFS_old

  # do the cleanup
  log.debug "Path=$dir ; Days=$days ; Ext: $ext"
  do_cleanup
done

# create html log and exit
create_html_log
