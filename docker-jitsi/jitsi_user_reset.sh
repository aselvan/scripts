#/bin/bash
#
# jitsi_user_reset.sh --- script to run under cron to reset users periodically
#
# Author:  Arul Selvan
# Version: Jun 26, 2020

my_name=`basename $0`
os_name=`uname -s`
JITSI_HOME="/var/jitsi"

# script to reset the password
jitsi_user_script="$JITSI_HOME/jitsi_user.sh"

# users list
users_list_file="$JITSI_HOME/jitsi_users.txt"
pwgen_bin="/usr/local/bin/pwgen"

# need pwgen
if [ $os_name != "Darwin" ]; then
  pwgen_bin="/usr/bin/pwgen"
fi

if [ ! -x $pwgen_bin ] ; then
  echo "[ERROR] missing required program '$pwgen_bin'"
  exit
fi

if [ -z "${CRED_PATH}" ] || [ ! -d "${CRED_PATH}" ] ; then
  echo "[ERROR] either CRED_PATH env variable is not set or not pointing to a valid directory!"
  exit
fi

if [ ! -x $jitsi_user_script ] ; then
  echo "[ERROR] missing required program '$jitsi_user_script'"
  exit
fi

# need users list
if [ ! -f $users_list_file ] ; then
  echo "[ERROR] users list file '$users_list_file' missing..."
  usage
else
  users_list=`cat $users_list_file`
fi

for user in $users_list ; do
  password=`$pwgen_bin 8 1`
  # just delete and add it back instead of update so non-existing users are created
  ( cd $JITSI_HOME ; $jitsi_user_script delete $user )
  ( cd $JITSI_HOME ; $jitsi_user_script create $user $password )
  echo "$password" > ${CRED_PATH}/$user.txt
done
