#!/usr/bin/env bash
#
# util.sh --- Wrapper for many useful utility commands.
#
# Author:  Arul Selvan
# Created: Jan 10, 2012
#
# Version History:
#   Jan 10, 2012 --- Original version (moved from .bashrc)
#   Dec 23, 2024 --- moved more from .bashrc
#   Dec 26, 2024 --- Added txt2mp3
#   Dec 27, 2024 --- Added knock
#

# version format YY.MM.DD
version=2024.12.27
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl util tools wrapper all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"

# commandline options
options="c:n:i:o:a:q:d:s:vh?"

command_name=""
supported_commands="tohex|todec|toascii|calc|rsync|knock|compresspdf|dos2unix|tx2mp3|vid2gif"
number=""
ifile=""
ofile=""
args=""
rsync_log_file="/tmp/$(echo $my_name|cut -d. -f1)_rsync.log"
rsync_opts="-rlptgoq --ignore-errors --no-specials --no-devices --delete-after --cvs-exclude --log-file=$rsync_log_file --temp-dir=/tmp --exclude=\"*.vmdk\""
pdf_quality="/ebook"
delay=3 # for vid2gif
host_port="" # for knock

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>   ---> command to run [see supported commands below]  
  -n <number>    ---> used by all commands that requires a number argument.
  -i <file/path> ---> input for commands require an input argument like toascii|rsync|compresspdf etc
  -o <file/path> ---> output for commands require output argument like rsync
  -a <arg>       ---> for commands like 'calc'
  -d <delay>     ---> frame delay used for vid2gif [Default: $delay]
  -s <host:port> ---> for 'knock'; need hostname and port knock open using fwknop client
  -q <quality>   ---> for 'compresspdf'; valid entries are "/printer|/ebook|/screen" [Default: $pdf_quality]
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

Supported commands: $supported_commands  
example: $my_name -c tohex -n 1000
  
EOF
  exit 0
}

function do_tohex() {
  if [ -z $number ] ; then
    log.error "tohex needs a number, see usage"
    usage
  fi
  log.stat "\tDecimal:Hex: $number:`printf "0x%x" $number`"
}

function do_todec() {
  if [ -z $number ] ; then
    log.error "todec needs a number, see usage"
    usage
  fi
  log.stat "\tHex:Decimal: $number:`printf "%d" $number`"
}

function do_toascii() {
  check_installed iconv
  if [ -z $ifile ] ; then
    log.error "toascii needs a unicode file to convert to ascii, see usage"
    usage
  fi
  iconv -t ASCII//TRANSLIT $file
}

function do_calc() {
  if [ -z $args ] ; then
    log.error "calc needs a expression argument, see usage"
    usage
  fi
  log.stat "\t$args = `echo "scale=6; \"$args\""|bc`"
}

function do_rsync() {
  if [ -z $ifile ] || [ -z $ofile ] ; then
    log.error "rsync needs input (source path) and output (destination path), see usage"
    usage
  fi
  log.stat "Running \"rsync $rsync_opts $ifile $ofile\" ..."
  log.stat "\tplease wait..."
  rm -rf $rsync_log_file
  rsync $rsync_opts $ifile $ofile
  log.stat "\trsync completed."
}

function do_compresspdf() {
  check_installed gs
  
  if [ -z $ifile ] ; then
    log.error "compresspdf needs input PDF file to compress, see usage"
    usage
  fi

  gs -sDEVICE=pdfwrite -dPDFSETTINGS="${pdf_quality}" -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$ifile.compressed $ifile
  if [ -f $ifile.compressed ] ; then
    mv $ifile.compressed $ifile
    log.stat "Compressed PDF file: $ifile"
  else
    log.error "Failed to compress: $ifile"
  fi

}

function do_dos2unix() {
  if [ -z $ifile ] ; then
    log.error "dos2unix needs input file, see usage"
    usage
  fi

  tr -d '\r' < $ifile > $ifile.dos2unix
  if [ $? -eq 0 ] ; then
    mv $ifile.dos2unix $ifile
    log.stat "Dos2Unix conversion successful: $ifile"
  else
    rm -rf $ifile.dos2unix
    log.error "Dos2Unix conversion failed: $ifile"
  fi
}

function do_txt2mp3() {
  check_installed lame
  
  if [ -z $ifile ] || [ -z $ofile ] ; then
    log.error "txt2mp3 needs input text file and name for output mp3 file, see usage"
    usage    
  fi

  log.stat "\tCreating MP3 file: $ofile.mp3 ..."
  cat $ifile | say -v Daniel -o $ofile.aiff
  lame $ofile.aiff $ofile.mp3 >> $my_logfile 2>&1
  rm $ofile.aiff
}

function do_vid2gif() {
  check_installed lame
  check_installed gifsicle

  if [ -z $ifile ] || [ -z $ofile ] ; then
    log.error "vid2gif needs input video file and name for output gif file, see usage"
    usage    
  fi

  log.stat "\tCreating animated GIF: $ofile ..."
  ffmpeg -i $ifile -pix_fmt rgb24 -r 15 -f gif - 2>/dev/null | gifsicle --optimize=3 --delay=$delay 2>/dev/null > $ofile 
}

function do_knock() {
  check_installed fwknop

  if [ -z $host_port ] ; then
    log.error "Need host:port for do_knock function, see usage"
    usage
  fi
  local host="${host_port%%:*}"
  local port="${host_port##*:}"
  if [ "$port" == "$host" ] ; then
    port=1863
    log.stat "\tPort not specified, using $port ..."
  fi
  # determine our egress (i.e. -R option on fwknop is not working so doing it ourself)
  local myip=`curl -s https://ifconfig.me`
  log.stat "\tRunning knock sequence on $host to open port# $port for $myip ..."
  fwknop -A tcp/$port -a $myip -D $host
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
    n)
      number="$OPTARG"
      ;;
    i)
      ifile="$OPTARG"
      ;;
    o)
      ofile="$OPTARG"
      ;;
    a)
      args="$OPTARG"
      ;;
    d)
      delay="$OPTARG"
      ;;
    q)
      pdf_quality="$OPTARG"
      ;;
    s)
      host_port="$OPTARG"
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
  tohex)
    do_tohex
    ;;
  todec)
    do_todec
    ;;
  toascii)
    do_toascii
    ;;
  calc)
    do_calc
    ;;
  rsync)
    do_rsync
    ;;
  compresspdf)
    do_compresspdf
    ;;
  dos2unix)
    do_dos2unix
    ;;
  txt2mp3)
    do_txt2mp3
    ;;
  vid2gif)
    do_vid2gif
    ;;
  knock)
    do_knock
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
