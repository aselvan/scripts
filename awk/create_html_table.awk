#
# create_html_table.awk 
# 
# Given a file of the form title=url on each line, this awk script will parse the 
# file and create a simple html file for a webserver to serve.
#
# sample run: cat <file_with_title_and_url> | awk -f create_html_table.awk
#
# Author: Arul Selvan
# Version: Apr 2, 2023
#

BEGIN {
  # the separator, can change to whatever separates title and url on each row
  FS = "=";

  # script version
  version = "create_html_table.awk v20230402";
  url_link = "https://github.com/aselvan/scripts/blob/master/awk/create_html_table.awk";

  # simple html header
  print "<html><head>";
  print " <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">";
  print "</head>";
  print "<body>";

  print "<h3>Created by <a href=\"" url_link "\">" version "</a><br>" ;
  print "<small><a href=\"https://selvansoft.com\">SelvanSoft, LLC</a></small><p>";

  # start table
  print "<table border=\"0\" width=\"90%\"> ";
  
}

{
  desc = trim($1);
  url  = trim($2);

  # no name available, then skip
  if ( desc == "" || url == "" ) next;

  # write a row
  print "<tr>";
  print "  <td width=\"30%\">" desc "</td>";
  print "  <td width=\"60%\"> <a href=\"" url "\">" url "</a></td>";
  print "</tr>";

}

function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s)  { return rtrim(ltrim(s)); }

END {
  # end table
  print "</table>";
  print "</body>";
  print "</html>";
}

