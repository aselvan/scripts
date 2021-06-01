#/bin/bash
#
# java_installed_versions.sh  --- simple script to check installed java is OpenJDK on Linux distros
#
#
# Author:  Arul Selvan
# Version: May 24, 2021
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
# NOTE: This is not a fool proof way as someone could have installed java anywhere like /opt/myjava
std_java_locations="/usr/lib/jvm/ /usr/java"

check_java() {
  location=$1
  java_dirs=`find $location -maxdepth 1 -type d |awk 'NR >1 {print $1; }'`
  if [ -z "$java_dirs" ]; then
    echo "[INFO] no java found at '$location' "
    continue
  fi

  for jdir in $java_dirs ; do
    if [ -x $jdir/bin/java ] ; then
      java_vendor=`$jdir/bin/java -version 2>&1 | awk '/Runtime/ {print $1;}'`
    elif [ -x $jdir/jre/bin/java ] ; then
      java_vendor=`$jdir/jre/bin/java -version 2>&1 | awk '/Runtime/ {print $1;}'`
    else
      java_vendor="NOT Java Installation"
    fi
    echo -e "\t$jdir \t| $java_vendor" | tee -a $log_file
  done
}

echo "[INFO] checking java @`hostname` ..."
for loc in $std_java_locations ; do
  if [ -d $loc ]; then
    check_java $loc
  fi
done
