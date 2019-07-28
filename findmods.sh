#!/bin/sh

# 
# Shell script for finding all the modified files 
#
# Author: Arul Selvan
# version: Aug 05, 2003.
#
VERSION="4.3.5"
LOCAL_PATH="/cygdrive/c/src/dspro-$VERSION"
BACKUP_PATH="/cygdrive/c/src/backup/$VERSION"
MOD_LIST_FILE=$BACKUP_PATH/modfiles.lst

cd $LOCAL_PATH/netw
find . \( -iname \*.cpp -o -iname \*.h -o -iname \*.rc \) -perm 700 -print >$MOD_LIST_FILE

cd $LOCAL_PATH/dspro
find . \( -iname \*.cpp -o -iname \*.h -o -iname \*.rc \) -perm 700 -print >>$MOD_LIST_FILE

