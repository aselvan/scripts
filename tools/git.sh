#!/usr/bin/env bash
################################################################################
#
# git.sh --- Wrapper for some git commands 
#
# Author:  Arul Selvan
# Created: Jan 31, 2025
#
################################################################################
#
# Version History:
#   Jan 31, 2025 --- Original version (moved from .bashrc)
#   Feb 16, 2025 --- Added listtag
#   Jun 30, 2025 --- Added shasum to create shasum for the release tag specified
#
################################################################################

# version format YY.MM.DD
version=25.06.30
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper for some git commands"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
release_archive="https://github.com/aselvan/scripts/archive"

# commandline options
options="c:t:m:vh?"

command_name=""
supported_commands="createtag|deletetag|movetag|listtag|shasum"
tag=""
comments=""

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>   ---> command to run [see supported commands below]  
  -t <tag>       ---> needed for all tag based commands like createtag movetag etc.
  -m <comment>   ---> comments in quote for tag commands
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

Supported commands: $supported_commands  
example: 
  $my_name -c createtag -t v25.06.12 -m "Jun 12, 2025 release"
  $my_name -c listtag
  $my_name -c deletetag -t v25.06.12
  $my_name -c movetag -t v25.06.12   # moves the tag to latest code
  $my_name -c shasum -t v25.06.12    # generates sha256 for the release code

EOF
  exit 0
}

function do_create_tag() {
  if [ -z $tag ] ; then
    log.error "createtag needs tag name, see usage"
    usage
  fi
  if [ -z "$comments" ] ; then
    comments="New tag ${tag}"
  fi

  log.stat "Creating tag $tag ..."
  git tag -a ${tag} -s -m "$comments" 
  git push origin master --tags
}

function do_delete_tag() {
  if [ -z $tag ] ; then
    log.error "createtag needs tag name, see usage"
    usage
  fi
  log.stat "Deleting tag $tag ..."
  git tag -d $tag
  git push origin --delete $tag
}

function do_move_tag() {
  if [ -z $tag ] ; then
    log.error "createtag needs tag name, see usage"
    usage
  fi
  if [ -z "$comments" ] ; then
    comments="Moveing ${tag} to latest commit at `date +"%I.%M%p on %b %d, %Y"`"
  fi
  log.stat "Moving tag $tag ..."
  git push origin :refs/tags/${tag}
  git tag -fa ${tag} HEAD -m "$comments"
  git push origin master --tags 
}

do_list_tag() {
  git tag -l -n
}

do_shasum() {
  if [ -z $tag ] ; then
    log.error "createtag needs tag name, see usage"
    usage
  fi
  local rel_url="$release_archive/refs/tags/$tag.tar.gz"
  curl -sL $rel_url | shasum -a 256
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    t)
      tag="$OPTARG"
      ;;
    m)
      comments="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing arguments, see usage below"
  usage
fi

# run different wrappes depending on the command requested
case $command_name in
  createtag)
    do_create_tag
    ;;
  deletetag)
    do_delete_tag
    ;;
  movetag)
    do_move_tag
    ;;
  listtag)
    do_list_tag
    ;;
  shasum)
    do_shasum
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
