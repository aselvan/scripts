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
std_java_location="/usr/lib/jvm/"

echo "[INFO] checking java versions on `hostname` ..." | tee $log_file

# NOTE: This is not a fool proof way as someone could have installed java anywhere like /opt/myjava
java_dirs=`find $std_java_location -maxdepth 1 -type d |awk 'NR >1 {print $1; }'`

for jdir in $java_dirs ; do
  if [ -x $jdir/bin/java ] ; then
    java_vendor=`$jdir/bin/java -version 2>&1 | awk '/Runtime/ {print $1;}'`
  elif [ -x $jdir/jre/bin/java ] ; then
    java_vendor=`$jdir/jre/bin/java -version 2>&1 | awk '/Runtime/ {print $1;}'`
  else
    java_vendor="NOT Java Installation"
  fi
  echo -e "$jdir \t| $java_vendor" | tee -a $log_file
done
