#!/usr/bin/env bash
#
# ps.sh --- simple wrapper for ps to show memory, cpu of top N processes
#
#
# Author:  Arul Selvan
# Version: Apr 4, 2021
#

os_name=`uname -s`
my_name=`basename $0`
count=15
options="mcp:t:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
pid=0

usage() {
  cat <<EOF
  
Usage: $my_name [options]
  
  -m         ==> show top $count process consuming memory
  -p <pid>   ==> show memory use of just the <pid> instead of all
  -c         ==> show top $count process consuming cpu [default w/ no args]
  -t <count> ==> set the number of process to list [must be first arg]
  -h         ==> help

  examples: 
    $my_name -t 10 -m
    $my_name -p 706
EOF
  exit 1
}

do_format_size() {
  local v=$1

  if [ $v -gt 1024 ] ; then
    v="$(((v+512)/1024))"
    if [ $v -gt 1024 ] ; then
      v="$(((v+512)/1024))"
      echo "$v GB"
    else 
      echo "$v MB"
    fi
  else
    echo "$v KB"
  fi
}

do_format_cmd() {
  local c=$1
  if [[ $c = -* ]] ; then
    c=$(echo -n $c | sed 's/^-//')
  fi

  c=`basename "$c"`

  echo $c
}

do_cpu() {
  local ps_opt="--sort -pcpu -eo pid=,pcpu=,comm="
  if [ $os_name = "Darwin" ] ; then
    ps_opt="-w -r -eo pid=,%cpu=,comm="
  fi

  printf "%s\t %s\t %s\n" PID %CPU COMMAND
  while read -r pid pcpu cmd; do
    cmd=`do_format_cmd "$cmd"`
    printf "%s\t %s\t %s\t %s\n" "$pid" "$pcpu" "$cmd"
  done < <(ps $ps_opt | head -n$count)
  exit
}

do_memory() {
  local ps_opt="--sort -rss -eo pid=,pmem=,rss=,vsz=,comm="
  local pid_opt=""
  if [ $os_name = "Darwin" ] ; then
    ps_opt="-w -m -eo pid=,%mem=,rss=,vsz=,comm="
  fi

  # if pid provided, use it
  if [ $pid -ne 0 ] ; then
    ps_opt="-w -m -o pid=,%mem=,rss=,vsz=,comm= -p $pid"
  fi
  printf "%s\t%s\t%s\t%s\t  %s\n" PID %MEM RSS VSZ COMMAND
  while read -r pid mem rss vsz cmd; do
    cmd=`do_format_cmd "$cmd"`
    rss=`do_format_size $rss`
    vsz=`do_format_size $vsz`
    printf "%s\t%s\t%s\t%s\t  %s\n" "$pid" "$mem" "$rss" "$vsz" "$cmd"
  done < <(ps $ps_opt $pid_opt | head -n$count)
  exit
}

# ---------------- main entry --------------------
# commandline parse
while getopts $options opt; do
  case $opt in
    c)
      do_cpu
      ;;
    m)
      do_memory
      ;;
    p)
      pid="$OPTARG"
      do_memory
      ;;
    t)
      count=$OPTARG
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

# by default w/ no arg, do_cpu which is typical thing one would like to do anyways.
do_cpu
