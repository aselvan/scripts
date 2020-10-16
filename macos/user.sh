#/bin/bash
#
# user.sh --- create/delete macOS users from commandline
#
# Author:  Arul Selvan
# Version: Feb 8, 2017
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="c:d:n:p:ha"
admin=0
uid=1000
# gid 20 is staff, 80 is admin by default on macOS
gid=20
min_username_length=3
user_name=""
full_name=""
password="${my_name}@${uid}"
action=0 # create=1, delete=2
dscl_bin="/usr/bin/dscl"

usage() {
  echo "Usage: $my_name -c <username> [-n <fullname>] [-p <password> -a | -d <username>"
  echo "  -c <username> --- create a osx user ex: joe note: no spaces and minumum of $min_username_length chars"
  echo "  -n <fullname> --- full name of the osx user ex: 'Joe Apple'. default: same as username"
  echo "  -p <password> --- the password to set for user. default: '$password'"
  echo "  -a            --- make the user 'admin' after creating"
  echo "  -d <username> --- delete the user. note: home directory will be wiped as well"
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

check_uid() {
  found=0

  echo "[INFO] checking for unused uid ..." | tee -a $log_file
  while [ $found -eq 0 ] ; do
    $dscl_bin . -list /Users UniqueID | awk '{print $2;}' | grep $uid >/dev/null 2>&1
    if [ $? -ne 0 ] ; then
      found=1
      echo "[INFO] found an unused UID $uid, it will be used for '$user_name'" | tee -a $log_file
    else
      ((uid=uid+1))
    fi
  done
}

check_username() {
  length=${#user_name}
  if [ $length -lt $min_username_length ] ; then
    echo "[ERROR] username length of $length is too small, must be at least $min_username_length "
    usage
  fi
}


create() {
  check_uid

  echo "[INFO] creating user '$user_name' ..." | tee -a $log_file
  $dscl_bin . -create /Users/$user_name UserShell /bin/bash
  if [ ! -z "$full_name" ] ; then
    $dscl_bin . -create /Users/$user_name RealName "$full_name"
  else
    $dscl_bin . -create /Users/$user_name RealName "$user_name"
  fi
  $dscl_bin . -create /Users/$user_name UniqueID $uid 
  $dscl_bin . -create /Users/$user_name PrimaryGroupID $gid
  $dscl_bin . -create /Users/$user_name NFSHomeDirectory /Users/$user_name
  $dscl_bin . -passwd /Users/$user_name $password
  if [ $? -ne 0 ] ; then
    echo "[ERROR] unable to set password for $user_name"| tee -a $log_file
  fi

  if [ $admin -eq 1 ] ; then
    # make this user part of admin group
    $dscl_bin . -append /Groups/admin GroupMembership $user_name
  fi

  # create home dir and setup permissions
  mkdir /Users/$user_name
  chown -R $user_name:staff /Users/$user_name
}

delete() {
  echo "[INFO] about to delete user $user_name ..." | tee -a $log_file
  read -p "Are you sure? (y/n) " -n 1 -r
  echo 
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    echo "[WARN] deleting user $user_name ..." | tee -a $log_file
    $dscl_bin . -delete /Users/$user_name
    echo "[WARN] removing user homedir (/Users/$user_name) ..." | tee -a $log_file
    rm -rf /Users/$user_name 
  else
    echo "[INFO] delete cancelled." | tee -a $log_file
  fi
}

# -------------------------- main -----------------------------
check_root
echo "[INFO] $my_name starting..." > $log_file

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    c)
      action=1
      user_name=$OPTARG
      check_username
      ;;
    d)
      action=2
      user_name=$OPTARG
      check_username
      ;;
    n)
      full_name=$OPTARG
      ;;
    p)
      password=$OPTARG
      ;;
    a)
      admin=1
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

if [ $action -eq 0 ] ; then
  echo "[ERROR] missing arguments!"
  usage
elif [ $action -eq 1 ]; then
  create
elif [ $action -eq 2 ]; then
  delete
else
  usage
fi
