#!/bin/bash
#
# create_thumbs.sh --- wrapper script to create thumbnail of html of images
#
# pre_req:
#   apt-get install tidy graphicsmagick-imagemagick-compat (Linux)
#   brew install tidy imagemagick (macOS)
#
# Author:  Arul Selvan
# Version: Dec 6, 2008
# Updated: Mar 14, 2021
#

os_name=`uname -s`
my_name=`basename $0`

options="e:t:d:q:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
extensions="JPG|jpg|JPEG|jpeg|PNG|png"
thumbs_per_row=6
title="title"
desc="thumbnail pictures"
convert_opt="-quality 75 -scale 100x75"
site_name="https://selvans.net/photos"
text_color="#000000"
bg_color="#ffffff"
link_color="#5555aa"
vlink_color="#bbbbee"
font_family="helvetica,arial,sans-serif"
index_file="index.html"
today=`date +%D`
root_dir=$(basename `pwd`)
abs_url="https://selvans.net/photos/$root_dir"
query_string=""

usage() {
  cat <<EOF
  
Usage: $my_name 
  -t <title>  ==> title string to use for generated images
  -d <desc>   ==> brief description to use for generated images
  -e <ext>    ==> extenstion list ex: "jpg|png" etc. [Default: "$extensions"]
  -q <string> ==> query string to append that webserver use to bypass authentication 
        [see /etc/apache2/sites-enabled/000-default-ssl.conf where string is used]

  example: $my_name -t "Title" -d "Our vacation pics" -e "JPG|png|jpeg"

EOF
  exit 1
}

check_prereq() {
  prereq_msg="  Linux: apt-get install tidy graphicsmagick-imagemagick-compat (or) macOS: brew install tidy imagemagick"
  if [[ ! -x /usr/local/bin/convert && ! -x /usr/bin/convert ]] ; then
    echo "[ERROR] required tool 'convert' does not exist, install with following" | tee -a $log_file
    echo "$prereq_msg" | tee -a $log_file
    exit 1
  fi
  if [ ! -x /usr/bin/tidy ] ; then
    echo "[ERROR] required tool 'tidy' does not exist, install with following" | tee -a $log_file
    echo "$prereq_msg" | tee -a $log_file
    exit 1
  fi
}

do_create_thumbs() {
  # write header
  mobile_friendly="<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"

  echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">" > $index_file
  echo "<html><head><title>$site_name - $title</title>" >> $index_file
  echo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" >> $index_file
  echo "<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css\">" >> $index_file
  #echo "<style type=\"text/css\">H1, P {font-family: $font_family}</style>" >> $index_file
  echo "</head> <body bgcolor=\"$bg_color\" text=\"$text_color\"" >> $index_file 
  echo "vlink=\"$vlink_color\" link=\"$link_color\">" >> $index_file
  echo "<h1 align=\"center\">$title</h1>" >> $index_file
  echo "<p align=\"center\"/>$desc" >> $index_file
  echo "<p align=\"center\"> <font color=\"red\">" >> $index_file
  echo "<small><b>NOTE:  </b></font>Click on a thumbnail for full image and/or click on WhatsApp icon to share</small>" >> $index_file

  table_start="<center><table border=0 cellspacing=5 cellpadding=7 align=\"center\" summary=\"\" ><tr>"
  local count=0

  # make sure thumb dir exists
  mkdir -p thumb

  # shopt below needed to expand ls argument properly
  shopt -s extglob
  
  # table start for thumbnail icons
  echo "$table_start <td></td>" >> $index_file
  for fname in `ls -vtr *.@($extensions)`; do
	  count_loop=`expr $count \% $thumbs_per_row`
	  if [ $count_loop -eq 0 ]; then
		  echo "</tr></table></center>$table_start" >> $index_file
    fi

	  count=`expr $count + 1`
	  echo "<td width=\"100\">" >> $index_file

	  thumb_fname=`basename $fname |cut -f 1 -d '.'`thumb.jpg
		echo "[INFO] convert $convert_opt $fname thumb/$thumb_fname ..." | tee -a $log_file
		convert $convert_opt $fname thumb/$thumb_fname >> $log_file 2>&1
    
    echo "<p align=\"center\">" >> $index_file
    echo "<a href=\"$fname\"><img src=\"thumb/$thumb_fname\"" >> $index_file
    echo "alt=\"$fname\"></a><br>" >> $index_file
    echo "<a href=\"whatsapp://send?text=$abs_url/$fname?$query_string\" target=\"_blank\">" >> $index_file
    echo "<i class=\"fa fa-whatsapp\" style=\"font-size:24px;color:green\">" >> $index_file
    echo "</i></a>" >> $index_file
    echo "</td>" >> $index_file
  done

  # finish table
  echo "</tr></table></center>" >> $index_file
  echo "<p align=\"center\">[<a href=\"../\">Photos</a>]   [<a href=\"../../\" target=\"_blank\">Home</a>]" >> $index_file

  # write a footer 
  echo "<blockquote> <hr align=\"center\" size=\"2\" noshade> <center><small>Copyright (c) 1999-2023" >> $index_file
  echo " <a href=\"https://selvans.net/\" target=\"_blank\" >https://selvans.net</a> <br>" >> $index_file
  echo "Last updated: $today </small> </center></blockquote>" >> $index_file
  echo "</body></html>" >> $index_file

  # tidy up html to be radable
  tidy -wrap 120 -m -i -q -raw --drop-empty-elements no $index_file >> $log_file 2>&1
}

# ---------------- main entry --------------------
echo "[INFO] $my_name starting ..." | tee $log_file
check_prereq

# commandline parse
while getopts $options opt; do
  case $opt in
    t)
      title="$OPTARG"
      ;;
    d)
      desc="$OPTARG"
      ;;
    e)
      extenstions="$OPTARG"
      ;;
    q)
      query_string="$OPTARG"
      ;;
    ?)
      usage
      ;;
    h)
      usage
      ;;
    esac
done

if [ -z "$query_string" ] ; then
  echo "[ERROR] missing query string for bypassing authentication"
  usage
fi

# create thumnail htmls
do_create_thumbs
