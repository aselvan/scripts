#!/usr/bin/env bash
################################################################################
#
# create_thumbs.sh --- wrapper script to create thumbnail of html of images
#
# pre_req:
#   apt-get install tidy graphicsmagick-imagemagick-compat (Linux)
#   brew install tidy imagemagick (macOS)
#
# Author:  Arul Selvan
# Version: Dec 6, 2008
################################################################################
#
# Version History:
#   Dec 6,  2008 --- Original version
#   Mar 14, 2021 --- Added FB, whatsAPP links?
#   Feb 25, 2024 --- Updated footer to include dynamic date & all our domains.
#   Apr 23, 2024 --- Added image_link classes and hard-code font size
#   Feb 27, 2025 --- Standard includes, remove .DS_Store, index.html thumb/ etc
################################################################################

# version format YY.MM.DD
version=2025.02.27
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper for some git commands"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="e:t:d:h"

extensions="JPG|jpg|JPEG|jpeg|PNG|png"
thumbs_per_row=6
title=""
desc=""
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
abs_url="https://selvans.net/php/fetch_photo.php?data=$root_dir"
remove_file_list="index.html thumb .DS_Store"

usage() {
  cat <<EOF
$my_name --- $my_title
 
Usage: $my_name [options]
  -t <title>  ==> title string to use for generated images [Required]
  -d <desc>   ==> brief description to use for generated images [Required]
  -e <ext>    ==> optional extenstion list ex: "jpg|png" etc. [default: "$extensions"]

example: 
  $my_name -t "Title" -d "Our vacation pics" -e "JPG|png|jpeg"

EOF
  exit 1
}

remove_files() {
  log.debug "Removing files that will be regenerated ..."
  for f in $remove_file_list ; do
    log.warn "  Removing $f ..."
    rm -rf $f
  done
}

check_prereq() {
  prereq_msg="  Linux: apt-get install tidy graphicsmagick-imagemagick-compat (or) macOS: brew install tidy imagemagick"
  if [[ ! -x /usr/local/bin/convert && ! -x /usr/bin/convert ]] ; then
    log.error "required tool 'convert' does not exist, install with following"
    log.error "$prereq_msg"
    exit 1
  fi
  if [ ! -x /usr/bin/tidy ] ; then
    log.error "required tool 'tidy' does not exist, install with following"
    log.error "$prereq_msg"
    exit 1
  fi
}

do_create_thumbs() {
  log.stat "Creating thumbnails..."

  # write header
  mobile_friendly="<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"

  echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">" > $index_file
  echo "<html><head><title>$site_name - $title</title>" >> $index_file
  echo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" >> $index_file
  echo "<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css\">" >> $index_file
  # some styles inline 
  echo "<style> 
    .image-link {
      max-width: 100%;
      height: auto;
    }
    H1 {
      font-family: $font_family ;
      font-size: 20px;
    }
    P {
      font-family: $font_family ;
      font-size: 15px;
    }
  </style>" >> $index_file
  #echo "<style type=\"text/css\">H1, P {font-family: $font_family}</style>" >> $index_file
  echo "</head> <body bgcolor=\"$bg_color\" text=\"$text_color\"" >> $index_file 
  echo "vlink=\"$vlink_color\" link=\"$link_color\">" >> $index_file
  echo "<h1 align=\"center\">$title</h1>" >> $index_file
  echo "<p align=\"center\"/>$desc" >> $index_file
  echo "<p align=\"center\"> <font color=\"red\">" >> $index_file
  echo "<small><b>NOTE:  </b></font>Click on a thumbnail for full image and/or click on WhatsApp or Facebook icon to share</small>" >> $index_file

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

		log.stat "  $fname -> thumb/$thumb_fname ..."
		convert $convert_opt $fname thumb/$thumb_fname >> $my_logfile 2>&1
    
    echo "<p align=\"center\">" >> $index_file
    echo "<a href=\"$fname\" class=\"image-link\"><img src=\"thumb/$thumb_fname\"" >> $index_file
    echo "alt=\"$fname\"></a><br>" >> $index_file
    
    # whatsapp share
    wa_share="whatsapp://send?text=${abs_url},${fname}"
    echo "<a href=\"${wa_share}\" target=\"_blank\">" >> $index_file
    echo "<i class=\"fa fa-whatsapp\" style=\"font-size:24px;color:green\">" >> $index_file
    echo "</i></a> &nbsp;" >> $index_file
    echo "" >> $index_file

    # facebook share
    fb_share="https://www.facebook.com/sharer/sharer.php?u=${abs_url},${fname}"
    echo "<a href=\"${fb_share}\" target=\"_blank\">" >> $index_file
    echo "<i class=\"fa fa-facebook\" style=\"font-size:24px;color:blue\">" >> $index_file
    echo "</i></a>" >> $index_file
    
    echo "</td>" >> $index_file
  done

  # finish table
  echo "</tr></table></center>" >> $index_file
  echo "<p align=\"center\">[<a href=\"../\">Photos</a>]   [<a href=\"../../\" target=\"_blank\">Home</a>]" >> $index_file

  # write a footer 
  echo "<blockquote> <hr align=\"center\" size=\"2\" noshade> <center><small> " >> $index_file
  echo "Copyright &copy; 1999-<script>document.write(new Date().getFullYear())</script>" >> $index_file
  echo " <a href=\"https://selvans.net/\" target=\"_blank\"> selvans.net</a> , " >> $index_file
  echo " <a href=\"https://selvansoft.com/\" target=\"_blank\"> selvansoft.com</a> <br> " >> $index_file
  echo "Last updated: <script>document.write(document.lastModified);</script> </small> </center></blockquote>" >> $index_file
  echo "</body></html>" >> $index_file

  # tidy up html to be radable
  tidy -wrap 120 -m -i -q -raw --drop-empty-elements no $index_file >> $my_logfile 2>&1
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

# ensure we have the helper bins installed
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
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
    esac
done

# check for required args
if [ "$title" == "" ] || [ "$desc" == "" ] ; then
  log.error "Missing required args! See usage below"
  usage
fi

# get rid of index, thumb & .DS_Store files
remove_files

# create thumnail htmls
do_create_thumbs
