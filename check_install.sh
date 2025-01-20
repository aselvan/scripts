#!/usr/bin/env bash
#
# check_install.sh --- Check if scripts repo is installed.
#
# Validate the install directory and check  necessary runtime environment 
# variables are available. This is only used in the brew tap formula at 
# link below.
#
# https://github.com/aselvan/homebrew-formulas/blob/master/Formula/aselvan-scripts.rb
#
# Author:  Arul Selvan
# Created: Jan 20, 2025
#
# Version History:
#   Jan 20, 2025 --- Initial version
#

# version format YY.MM.DD
version=25.01.20

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] && [ -f $scripts_github/check_install.sh ] ; then
  echo "Scripts: Installed"
  exit 0
else
  echo "Scripts: Not Installed"
  exit 1
fi

