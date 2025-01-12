#
# awk script to parse and pic google contact CSV file fields to be 
# imported into callcenter phone book which is very stupid simple
# format: <speed_dial#>,<first last>, <phone>,<groupname>
#
# Need to get the following from Google contact CSV
#  $2 firstname
#  $4 lastname
#  $40 cell
#  $42 home
#
# sample run: cat <google_contact_export_file> | awk -f google_contact_to_callcentric.awk
#
# Author: Arul Selvan
# Version: Nov 13, 2016
# Version: Nov 13, 2021 
# 
# NOTE: This is not working because of multi-line issue. Changed the code to expect only
#   the needed columns name,cell,home by massaging (removing all columns) w/ Microsoft XL
#   Make sure run dos2unix since XL sticks in ^Ms, also run iconv to remove unicode chars
#   iconv -c -f utf-8 -t ascii contacts.csv > contacts.csv.nounicode
#

BEGIN {
  FS = ",";
}
{
  name = $1;
  cell = $2
  home = $3;

  # skip header
  if ( NR == 1 ) next;
  
  # no name available, then skip
  if ( name == "" ) next;
 
  # google export writes line feed for some address fields makeing
  # it two lines screwing with us. Still have to edit the output manually!!!
  # before we import to callcenter.
  # TODO: So bottomline is this not working because of multi-line, so use Excel for now!) 

  # one line for home and cell
  if (home != "") {
    # call centric does not like phone formating, so strip it
    gsub(/-/, "", home);
    gsub(/\++/, "", home);
    gsub(/ /, "", home);
    gsub(/\(/, "", home);
    gsub(/\)/, "", home);
    print "," "\"" name "\""  "," home ;
  }

  if (cell != "") {
    # call centric does not like phone formating, so strip it
    gsub(/-/, "", cell);
    gsub(/\++/, "", cell);
    gsub(/ /, "", cell);
    gsub(/\(/, "", cell);
    gsub(/\)/, "", cell);
    print "," "\"" name "\""  "," cell ;
  }
}

END {
#  print "";
}
