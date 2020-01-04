#!/bin/sh
#
# Script to add a new account for SFTP access.
# create account, limit to just sftp,scp (no shell), access only by IP based, restrict
# to ssh user etc.
# 
# Author:  Arul Selvan
# Version: 5/26/2010
#

app_name=`basename $0`
app_path=`dirname $0`
uid=`id -u`
log_file="/tmp/${app_name}_${USER}.out"
user_name=
user_description=
password=
update_configs=

usage(){
    echo "Usage: $app_name --user_name <user_name> <--update_configs>|<--password <password_in_plain> --user_description <sometext>> [--help]"
    exit
}

create_account() {
    pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)

    # create and setup directory structure
    echo "Setting up new user '${user_name}' ..." > $log_file
    useradd -c "$user_description" -s /usr/bin/rssh -p $pass $user_name >>$log_file 2>&1 
    rc=$?
    if [ $rc -ne 0 ] ; then
        echo "ERROR: useradd failed, error=$rc, check $log_file for any additional errors..." >>$log_file 2>&1
        echo "  ERROR: useradd failed, error=$rc, check $log_file for any additional errors..."
        echo "  Exiting ..."
        exit 
    fi

    mkdir -p /home/${user_name}/.ssh >>$log_file 2>&1
    mkdir -p /home/${user_name}/incoming >>$log_file 2>&1
    mkdir -p /home/${user_name}/outgoing >>$log_file 2>&1
    mkdir -p /home/${user_name}/backup >>$log_file 2>&1
    mkdir -p /home/${user_name}/tmp >>$log_file 2>&1
    mkdir -p /home/${user_name}/ysdx >>$log_file 2>&1

    # setup permission, ownership
    chown -R ${user_name}:${user_name} /home/${user_name}/.ssh >>$log_file 2>&1
    chown -R ${user_name}:${user_name} /home/${user_name}/incoming >>$log_file 2>&1
    chown -R ${user_name}:${user_name} /home/${user_name}/outgoing >>$log_file 2>&1
    chown -R ${user_name}:${user_name} /home/${user_name}/backup >>$log_file 2>&1
    chown -R ${user_name}:${user_name} /home/${user_name}/tmp >>$log_file 2>&1
    chown -R ${user_name}:${user_name} /home/${user_name}/ysdx >>$log_file 2>&1
}

update_configs() {
    # copy system keys, configuration etc.
    cp $app_path/authorized_keys /home/${user_name}/.ssh/. >>$log_file 2>&1
    chmod 700 /home/${user_name}/.ssh >>$log_file 2>&1
    chmod 644 /home/${user_name}/.ssh/authorized_keys >>$log_file 2>&1
    chown -R ${user_name}:${user_name} /home/${user_name}/.ssh/authorized_keys >>$log_file 2>&1

    cp /etc/hosts.allow /tmp/hosts.allow.backup >>$log_file 2>&1
    cp hosts.allow /etc/. >>$log_file 2>&1
    chmod 644 /etc/hosts.allow >>$log_file 2>&1

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup >>$log_file 2>&1
    cp sshd_config /etc/ssh/. >>$log_file 2>&1
    chmod 600 /etc/ssh/sshd_config >>$log_file 2>&1

    # restart sshd
    echo "Restarting sshd ..."
    /etc/init.d/sshd restart
}

if [ $uid -ne 0 ]; then
    echo "Sorry, you must be root to execute this script!"
    exit
fi

# parse commandline args
while [ "$1" ]
do
  if [ "$1" = "--user_name" ]; then
    shift 1
    user_name=$1
    shift 1
  elif [ "$1" = "--user_description" ]; then
    shift 1
    user_description=$1
    shift 1
  elif [ "$1" = "--password" ]; then
    shift 1
    password=$1
    shift 1
  elif [ "$1" = "--update_configs" ]; then
    update_configs=1
    shift 1 
  elif [ "$1" = "--help" ]; then
    usage
  else
    echo "Unknown option: $1"
    usage
  fi
done

# check required argument (must have)
if [ -z "$user_name" ] ; then
   usage
fi

# make sure the files we need are there.
if [ ! -e $app_path/authorized_keys -o ! -e ${app_path}/hosts.allow -o  ! -e ${app_path}/sshd_config ]; then
    echo "Missing one or more required files, please contact Yieldstar team"
    echo "Files required: authorized_keys, hosts.allow, sshd_config"
    exit
fi

if [ "$update_configs" = "1" ]; then
    echo "Updating config files only, i.e. no account creation is done." 
    update_configs
    exit
fi

if [ -z "$user_description" -o -z "$password" ] ; then
   usage
fi


echo "About to create account for '$user_name' ... "
echo ""
echo -n "Are you sure you want to continue? [no]: "
read ans
if [ "$ans" != "yes" ]; then
  echo "Aborting..."
  echo ""
  exit
fi

create_account
update_configs

echo "Done."
echo "Check for any errors on log file at: $log_file"
