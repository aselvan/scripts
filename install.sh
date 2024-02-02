#!/usr/bin/env bash
#
# install.sh --- Install script to setup this repo.
#
# PreReq: git must be installed
# OS: Linux or MacOS
#
# Author:  Arul Selvan
# Version History:
#   Feb 2, 2024 --- Initial version
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=24.02.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Script to download and setup to run scripts repo"
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
verbose=0

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# commandline options
options="p:vh?"

# default install path
script_home="${HOME}/src"
scripts_dir="scripts.github"
bashrc="${HOME}/.bashrc"

# ripo home
repo="https://github.com/aselvan/scripts.git"

usage() {
cat << EOF

$my_name - $my_title

Usage: $my_name [options]
  -p <path> ---> Install path [Default: $script_home]
  -v        ---> enable verbose, otherwise just errors are printed
  -h        ---> print usage/help

example: $my_name -p $script_home
  
EOF
  exit 0
}

# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      script_home="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

echo "$my_version" | tee $my_logfile
# check if git is available
which git 2>&1 >/dev/null
if [ $? -ne 0 ] ; then
  echo "[ERROR] missing git which is required. Install git and try again." | tee -a $my_logfile
  exit 1
fi

# check if path is already there and request to remove it first.
if [ -d ${script_home}/${scripts_dir} ] ; then
  echo "[WARN] target path (${script_home}/${scripts_dir}) already exists, remove it and try again" | tee -a $my_logfile
  exit 2
fi
mkdir -p ${script_home}/${scripts_dir}

cd ${script_home} || exit 3

# clone the repo
echo "[INFO] cloning repo $repo ..."
git clone $repo $scripts_dir 2>&1 | tee -a $my_logfile

# setup path in .bashrc
echo "[INFO] adding PATH to $bashrc ..."
SH="${script_home}/${scripts_dir}"
path_to_append="export PATH=\"\$PATH:$SH/utils:$SH/security:$SH/tools:$SH/linux:$SH/macos:$SH/firewall\""
cp $bashrc ${bashrc}.backup
echo "" >> $bashrc
echo "# ------------- Added by $my_version ------------- " >> $bashrc
echo $path_to_append >> $bashrc
echo "" >> $bashrc
echo "[INFO] install done"
exit 0
