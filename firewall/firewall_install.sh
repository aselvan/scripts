#!/usr/bin/env bash
################################################################################
#
# firewall_install.sh --- install firewall rules on MacOS
#
# NOTE: Unfortunately, every MacOS update wipes the custom firewall rule we add 
# in /etc/pf.conf so we need to repeat this after every MacOS update. You can 
# always edit the /etc/pf.conf file as expliained in the README.md file or use 
# this handy handy script to make it easy to reinstall the rules. 
#
# Author:  Arul Selvan
# Version: Jul 7, 2023
#
################################################################################
#
# Version History:
#   Jul 7,  2023 --- Original version
#   Jan 23, 2025 --- Use standard includes for logging, documentation update etc
#
################################################################################

# version format YY.MM.DD
version=25.01.29
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Install firewall rules on MacOS"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="r:vh?"

anchor_name="com.selvansoft"
anchor_path="/etc/pf.anchors"
pf_conf="/etc/pf.conf"
rules_file="pf_rules_simple.conf"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -r <file>  ---> firewall rules file name to install [Default: $rules_file]
  -v         ---> verbose mode prints info messages, otherwise just errors are printed
  -h         ---> print usage/help

  example: $my_name
  
EOF
  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

# ensure root access
check_root

# parse commandline options
while getopts $options opt ; do
  case $opt in
    v)
      verbose=1
      ;;
    r)
      rules_file="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check if rules file is valid
if [ ! -f $rules_file ] ; then
  log.error "Invalid or non-existent rules file: ${rules_file}"
  usage
fi

# copy rules file
log.stat "Copying rules file $rules_file ..."
cp $rules_file $anchor_path/.

# check if rules file already installed, if so bail out
cat $pf_conf |grep $anchor_name 2>&1 >/dev/null
if [ $? -eq 0 ] ; then
  log.warn "Firewall rules appear to be already installed, check ${pf_conf}"
  exit 1
fi

log.stat "Modifying $pf_conf to include the rules ..."
# append rules
cat << EOF >> $pf_conf

#
# ------------------------ Custom firewall rules anchor ------------------------
# Disclaimer: This is a free utility from selvansoft.com provided "as is" without 
# warranty of any kind, expressed or implied. Use it at your own risk!
#
# Source: https://github.com/aselvan/scripts/tree/master/firewall
#
anchor "$anchor_name"
load anchor "$anchor_name" from "$anchor_path/`basename $rules_file`"

EOF

log.stat "Firewall rules are installed on ${pf_conf}" $green
log.stat "You now can run 'sudo firewall start' for rules take effect immediately."
