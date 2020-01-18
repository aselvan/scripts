#!/usr/bin/perl
#
##################################################################################
# Disclaimer
#
# This script comes without warranty of any kind. Use them at your own risk. 
# I assume no liability for the accuracy, correctness, completeness, or usefulness 
# of any information provided by this site nor for any sort of damages using these 
# scripts may cause.
#
##################################################################################
# libre_app.pl
#
#  Simple perl script reads and parses the FreeStyle Libre CGM (Abbots Lab) 
#  as well as LiApp data and loads into a sqlite db. Options are available 
#  to calculate a1c for the entire dataset or by month, week etc.
#
#  NOTE: The BG data can be exported by FreeStyle desktop applicaiton 
#  i.e. topmenu->export. The file is space delimited with 3 rows of header.
#
# Usage:
# The first example loads libre data, the second one liapp data and the
# last one just shows A1c. The libre-db.sqlite DB is expected be in the 
# current directory; alternatively, you can use --db <libre DB path>
#
#   libre_app.pl --import <libre_data_file>
#   libre_app.pl --import <liapp_data_file> --type liap 
#   libre_app.pl 
#
# Here is the simple schema used in the sqlite DB
#
#    sqlite> select * from sqlite_master;
#    table|bgtable|bgtable|2|CREATE TABLE `bgtable` (
#	      `timestamp`	TEXT CHECK(datetime(timestamp) is not null),
#	      `bg`	INTEGER NOT NULL,
#	      PRIMARY KEY(`timestamp`)
#    )
#    index|sqlite_autoindex_bgtable_1|bgtable|3|
# 
# Author:  Arul Selvan
# 
# Version History:
# v1.0 Jan 18, 2018 -- initial version
# v2.0 Feb 25, 2018 -- moved data to sqlight DB, added monthly weekly options
# v2.1 Apr 1,  2018 -- implemented export to csv 
# v2.2 Apr 8,  2018 -- added average and stddev on monthly and weekly reports
# v2.3 Aug 18, 2018 -- daily option
# v2.4 Dec 21, 2019 -- added coefficent of variance measure.
# v2.5 Jan 08, 2020 -- added disclaimer and version number
# v3.0 Jan 18, 2020 -- reworked by month, weeks, days to do entire period
# v3.1 Jan 18, 2020 -- updated the usage
#
##############################################################################
use strict;
use warnings;

# imports 
use File::Basename;
use DBI;

# version
my $version_number="v3.1 date: 1/18/2020";
my $script_name = basename($0);

# commandline parsing
use Getopt::Long;
# default DB file name (expect in current directory)
my $db_file = "libre-db.sqlite";
my $db_handle;
my $db_user     = "";
my $db_password = "";
my $insert_sql = "insert into bgtable (timestamp, bg) values (?,?)";
my $debug=0;
my $today = `date +%m/%d/%Y" "%l:%M:%S" "%p`;
chomp $today;
my $minBGcount=30;
my $type='libreview';
my $fname;
my $export_fname;
my $year=0;
my $months=0;
my $weeks=0;
my $days=0;

# calculate average
sub average {
  my($data) = @_;
  if (not @$data) {
    die("Empty array!");
  }
  my $total = 0;
  foreach (@$data) {
    $total += $_;
  }
  my $average = $total / @$data;
  return $average;
}

# calculate std deviation
sub stdev {
  my($data) = @_;
  if(@$data == 1){
    return 0;
  }
  my $average = &average($data);
  my $sqtotal = 0;
  foreach(@$data) {
    $sqtotal += ($average-$_) ** 2;
  }
  my $std = ($sqtotal / (@$data-1)) ** 0.5;
  return $std;
}

# calculate coefficient of variation
sub cofvar {
  my($data) = @_;
  if(@$data == 1){
    return 0;
  }
  my $average = &average($data);
  my $sd = &stdev($data);
  my $cv = ($sd / $average) * 100;
  return $cv;
}

# calculate a1c 
sub a1c {
  # A1c = (46.7 + average_blood_glucose_in_mg_dl) / 28.7
  my $ave = $_[0];
  my $a1c = (46.7 + $ave) / 28.7;
  return $a1c;
}

sub format_dt_libre {
  my ($date, $time) = @_;
  # change '/' to '-'
  $date =~ s/\//-/g;
  return $date . " " .$time;
}

sub format_dt_libreview {
  my ($dt) = @_;
  # flip date to YYYY-MM-DD TIME from the format: "07-04-2019 2:50 PM"
  my @dateArray = split(/[-\s]+/, $dt);
  my $date = $dateArray[2] . "-" . $dateArray[0] . "-" . $dateArray[1]; # YYYY-MM-DD

  # convert time to 24hr format i.e. "2:50 PM" to "14:50"
  my @timeArray = split(/[\s:]+/,$dt); # timeArray[1] & timeArray[2] & timeArray[3]
  my $hour = $timeArray[1];
  my $min = $timeArray[2];
  $hour -= 12 if ($timeArray[3] eq 'AM' && $hour == 12);
  $hour += 12 if ($timeArray[3] eq 'PM' && $hour != 12);
  
  return $date . " " . $hour . ":" . $min;
}


sub format_dt_liapp {
  my ($date, $time) = @_;
  # string is DD.MM.YYY format need YYYY-MM-DD
  my @ds = split(/\./, $date);
  return $ds[2] . "-" . $ds[1] . "-" . $ds[0] . " " . $time;
}


sub print_import_results {
  my ($total,$imported,$duplicates,$errors) = @_;
  
  print "Successfully imported into SQLlite DB\n";
  print "\tTotal records found:  $total\n";
  print "\tDuplicate (skipped):  $duplicates\n";
  print "\tError on importing:   $errors\n";
  print "\tActually imported:    $imported\n";

  my $row_count = $db_handle->selectrow_array(qq{ select count(*) from bgtable});
  print "\tTotal records in DB:  $row_count\n";

}

# function to import from libre reader exported data
sub import_libre_data {
  open (my $fh, $fname) or die "Could not open file '$fname'";
  my $i = 0;
  my $duplicates=0;
  my $imported=0;
  my $errors=0;
  my $total=0;

  my $ps = $db_handle->prepare($insert_sql);

  while (my $row = <$fh>) {
    chomp $row;
    $i++;
    # skip the header (i.e. first 3 lines)
    if ( $i <= 3 ) {
      next;
    }
  
    # tokenize with space (stupid libre using space delimited files!)
    # column details: 0=ID; 1=date; 2=time; 3=type; 4=bg; 
    my @rowArray = split(/\s+/, $row);

    # 3=type is 0=realtime data; 1=manual data; 5=error; 6=sensor not ready
    # skip rows who's type is not 0 or 1
    if ( $rowArray[3] != 0 && $rowArray[3] != 1 ) {
      next;
    }
    
    $total++;
    # add to db
    $ps->execute(&format_dt_libre($rowArray[1],$rowArray[2]), $rowArray[4]);
    if ($ps->err) {
      if ( $DBI::errstr eq "UNIQUE constraint failed: bgtable.timestamp" || $DBI::err == 19 ) {
        if ($debug == 1) { print "### ERROR code: $DBI::err\n"; }        
        $duplicates++;
      }
      else { 
        if ($debug == 1) { print "### ERROR code: $DBI::err\n"; }
        $errors++;
      }
    }
    else {
      $imported++;
    }
  }
  $db_handle->commit();

  print_import_results($total,$imported,$duplicates, $errors);
  
}

# function to import from librewview cloud data www2.libreview.com.
sub import_libreview_data {
  open (my $fh, $fname) or die "Could not open file '$fname'";
  my $i = 0;
  my $duplicates=0;
  my $imported=0;
  my $errors=0;
  my $total=0;

  my $ps = $db_handle->prepare($insert_sql);

  while (my $row = <$fh>) {
    chomp $row;
    
    $i++;
    # skip the header (i.e. first 2 lines)
    if ( $i <= 2 ) {
      next;
    }
    
    #also remove \r\n & \000 [stupid libreview cloud export adds null char]
    $row =~ s/[\r\n\000]//sg;
    
    # check the length for some arbitarly lenth like 10
    my $slen = length($row);
    if ( $slen <= 10 ) {
      next;
    }
    
    # tokenize w/ coma (ex: FreeStyle LibreLink,a8d3eff9-b1bd-4ac0-9364-a320ab05dd8a,07-04-2019 2:50 PM,0,100,,,,,,,,,,,,,,,)
    # column details: 0=device name; 1=devid; 2=date; 3=type; 4=bg; 
    my @rowArray = split(/,/, $row);    

    # 3=type is 0=realtime data; 1=manual data; 5=error; 6=sensor not ready
    # skip rows who's type is not 0 or 1
    if ( $rowArray[3] != 0 && $rowArray[3] != 1 ) {
      next;
    }
    
    $total++;

    # for some stupid reason if manual scan i.e. type=1 there is additonal comma!
    if ($rowArray[3] == 1) {
      $rowArray[4] = $rowArray[5];
    }

    # add to db
    $ps->execute(&format_dt_libreview($rowArray[2]), $rowArray[4]);
    if ($ps->err) {
      if ( $DBI::errstr eq "UNIQUE constraint failed: bgtable.timestamp" || $DBI::err == 19 ) {
        if ($debug == 1) { print "### ERROR code: $DBI::err\n"; }        
        $duplicates++;
      }
      else { 
        if ($debug == 1) { print "### ERROR code: $DBI::err\n"; }
        $errors++;
      }
    }
    else {
      $imported++;
    }
  }
  $db_handle->commit();

  print_import_results($total,$imported,$duplicates, $errors);
  
}



# function to import liapp (andriod/ios app some german guy wrote)
sub import_liapp_data {
  open (my $fh, $fname) or die "Could not open file '$fname'";
  my $i = 0;
  my $duplicates=0;
  my $imported=0;
  my $total=0;
  my $errors=0;  

  my $ps = $db_handle->prepare($insert_sql);

  while (my $row = <$fh>) {
    chomp $row;
    $i++;
    # skip the header (i.e. first 1 lines)
    if ( $i <= 1 ) {
      next;
    }
  
    # tokenize with ';'
    # column details: 0=date 1=time; 2=bg
    my @rowArray = split(/;/, $row);

    $total++;
    # add to db;
    $ps->execute(&format_dt_liapp($rowArray[0],$rowArray[1]), $rowArray[2]);
    if ($ps->err) {
      if ( $DBI::errstr eq "UNIQUE constraint failed: bgtable.timestamp" || $DBI::err == 19 ) {
        if ($debug == 1) { print "### ERROR code: $DBI::err\n"; }        
        $duplicates++;
      }

      else {
        if ($debug == 1) { print "### ERROR code: $DBI::err\n"; }
        $errors++;
      }
    }
    else {
      $imported++;
    }
  }
  $db_handle->commit();
  
  print_import_results($total,$imported,$duplicates, $errors);

}

sub usage {
  print "Usage: libre_app.pl [options]\n";
  print "  where options are: \n";
  print "   --import <filename> --type <liapp|libre|libreview> [libre=reader data; libreview=cloud export - default]\n";
  print "   --export <filename>\n";
  print "   --db <dbname> \n";
  print "   --months <number of months> \n";
  print "   --weeks <number of weeks> \n";
  print "   --days <number of days> \n";
  print "   --help usage\n";
  print "   --debug 1 print debug message\n";
  exit 0;
}

sub print_version {
  print "$script_name $version_number\n";
  exit 0;
}

sub read_db_data {
  my $sql = shift;
  my @bgData;
  my $pps = $db_handle->prepare($sql);
  $pps->execute();

  while (my @row = $pps->fetchrow_array) {
    push @bgData, $row[0];
  }
  return @bgData;
}

sub export_data {
  # open export file for wriging
  open(my $fh, '>',$export_fname);
  print $fh "# Libre Freestyle CSV data export, v1.0\n";
  print $fh "# Exported on: $today\n";
  print $fh "Date,BG\n";

  my $pps = $db_handle->prepare("select timestamp, bg from bgtable");
  $pps->execute();
  my $count=0;
  while (my @row = $pps->fetchrow_array) {
    print $fh "$row[0],$row[1]\n";
    $count++;
  }
  close $fh;
  print "Exported total of $count rows.\n";
}

sub compute_a1c_all {
  my @bgData = read_db_data("select bg from bgtable");
  my $bgCount = @bgData;

  # get the data duration
  my @dateFrom = read_db_data("select timestamp from bgtable order by timestamp asc limit 1");
  my @dateTo = read_db_data("select timestamp from bgtable order by timestamp desc limit 1");
  my @totalDays = read_db_data("select julianday('$dateTo[0]') - julianday('$dateFrom[0]')");

  my $bgAve = sprintf( "%.02f", &average(\@bgData) );
  my $bgStd = sprintf( "%.02f  (SD ref range 10-26 for non-diabetes)", &stdev(\@bgData) );
  my $bgCof = sprintf( "%.02f  (CV ref range 19-25 for non-diabetes)", &cofvar(\@bgData) );
  my $a1c = sprintf( "%.02f", &a1c($bgAve) );
  my $numDays = sprintf("%.02f",$totalDays[0] );
  #my $numDays = sprintf("%.02f",($bgCount/(4*24)) );

  print " --- A1C for ALL data found in DB ---\n";
  print "BG data range:       $dateFrom[0] ---> $dateTo[0]\n";
  print "BG data total:       $numDays days.\n";
  print "BG data count:       $bgCount\n";
  print "BG data average:     $bgAve\n";
  print "BG data SD:          $bgStd\n";
  print "BG data CV:          $bgCof\n";
  print "Your predicted A1C:  $a1c\n\n";

  if ($bgCount < $minBGcount) {
    print "CAUTION: Your BG sample count of $bgCount is too small to have meaningfull A1C calculation. \n";
    print "   Collect more number of BG samples and rerun this script.\n";
  }
}

# DEPRICATED:
sub compute_a1c_monthly_old {
  my $month;
  my @bgData;
  my $bgCount;

  print "--- A1C by month --- \n";
  print "Month\tCount\tAverage\tSD\tCV\tA1C\n";
  for ($month=1; $month<=12; $month++) {
    my $month_filter=sprintf("'%02d/$year'", $month);
    if ($debug == 1) { print "[DEBUG] Month filter: $month_filter\n"; }    
    my $sql = "select bg from bgtable where strftime('%m/%Y',timestamp) = " . $month_filter;
    @bgData = read_db_data($sql);
    $bgCount = @bgData;
    if ( $bgCount >= $minBGcount) {
      my $bgAve = sprintf( "%.02f", &average(\@bgData) );
      my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
      my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
      my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
      # strip the ''' character surrounding month
      $month_filter =~ s/\'//g;
      print "$month_filter\t$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
    }
    else {
      #print "$month_filter\t<NO DATA>\n";
    }
  }
}

# calculate monthly going back to # months specified and for the entire period.
sub compute_a1c_monthly {
  my $month;
  my @bgData;
  my $bgCount;

  # now, calculate for the entire period
  print "--- A1C by month starting with $months months before to current --- \n";
  print "Months\tCount\tAverage\tSD\tCV\tA1C\n";
  my $num_months=$months;
  
  while ($months > 0) {
    my $month_from = sprintf("datetime('now' , '-%d days')",$months * 30);
    my $month_to   = sprintf("datetime('now' , '-%d days')",($months-1)*30);
    if ($debug == 1) { print "[DEBUG] Month from: $month_from to: $month_to\n"; }    

    my $sql="select bg from bgtable where timestamp between $month_from and $month_to";

    @bgData = read_db_data($sql);
    $bgCount = @bgData;
    if ( $bgCount >= $minBGcount) {
      my $bgAve = sprintf( "%.02f", &average(\@bgData) );
      my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
      my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
      my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
      print "$months\t$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
    }
    else {
      #print "$months\t<NO DATA>\n";
    }
    $months--;
  }

  # now, calculate for the entire period
  print "\n--- A1C for the entire period in the last $num_months months --- \n";
  print "Count\tAverage\tSD\tCV\tA1C\n";
  my $month_from = sprintf("datetime('now' , '-%d days')",$num_months * 30);
  my $month_to   = sprintf("datetime('now' , '-%d days')",0);
  if ($debug == 1) { print "[DEBUG] Month from: $month_from to: $month_to\n"; }    
  my $sql="select bg from bgtable where timestamp between $month_from and $month_to";

  @bgData = read_db_data($sql);
  $bgCount = @bgData;
  if ( $bgCount >= $minBGcount) {
    my $bgAve = sprintf( "%.02f", &average(\@bgData) );
    my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
    my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
    my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
    print "$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
  }

}

sub compute_a1c_weekly {
  my @bgData;
  my $bgCount;

  print "--- A1C going back to $weeks weeks from $today --- \n";
  print "Week\tCount\tAverage\tSD\tCV\tA1C\n";
  my $num_weeks=$weeks;
  
  while ($weeks > 0) {
    my $week_from = sprintf("datetime('now' , '-%d days')",$weeks * 6);
    my $week_to   = sprintf("datetime('now' , '-%d days')",($weeks-1)*6);
   
    if ($debug == 1) { print "[DEBUG] week from: $week_from to: $week_to\n"; }        
   
    my $sql="select bg from bgtable where timestamp between $week_from and $week_to";
    @bgData = read_db_data($sql);
    $bgCount = @bgData;
    if ( $bgCount >= $minBGcount) {
      my $bgAve = sprintf( "%.02f", &average(\@bgData) );
      my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
      my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
      my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
      print "$weeks\t$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
    }
    else {
      print "$weeks\t$bgCount\t<SAMPLE_SIZE_TOO_SMALL>\n";      
    }
    $weeks--;
  }

  # now, calculate for the entire period
  print "\n--- A1C for the entire period in the last $num_weeks weeks --- \n";
  print "Count\tAverage\tSD\tCV\tA1C\n";

  my $week_from = sprintf("datetime('now' , '-%d days')",$num_weeks * 6);
  my $week_to   = sprintf("datetime('now' , '-%d days')",0);
   
  if ($debug == 1) { print "[DEBUG] week from: $week_from to: $week_to\n"; }        
   
  my $sql="select bg from bgtable where timestamp between $week_from and $week_to";
  @bgData = read_db_data($sql);
  $bgCount = @bgData;
  if ( $bgCount >= $minBGcount) {
    my $bgAve = sprintf( "%.02f", &average(\@bgData) );
    my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
    my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
    my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
    print "$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
  }
  else {
    print "$bgCount\t<SAMPLE_SIZE_TOO_SMALL>\n";      
  }

}

sub compute_a1c_days {
  my @bgData;
  my $bgCount;

  print "--- A1C going back to $days days from $today --- \n";
  print "Days\tCount\tAverage\tSD\tCV\tA1C\n";
  my $num_days=$days;
  while ($days > 0) {
    my $days_from = sprintf("datetime('now' , '-%d days')",$days);
    my $days_to   = sprintf("datetime('now' , '-%d days')",($days-1));
    my $sql="select bg from bgtable where timestamp between $days_from and $days_to";
    @bgData = read_db_data($sql);
    $bgCount = @bgData;
    if ( $bgCount >= $minBGcount) {
      my $bgAve = sprintf( "%.02f", &average(\@bgData) );
      my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
      my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
      my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
      print "$days\t$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
    }
    else {
      print "$days\t$bgCount\t<SAMPLE_SIZE_TOO_SMALL>\n";
    }
    $days--;
  }

  # now, calculate for the entire period
  print "\n--- A1C for the entire period in the last $num_days days --- \n";
  print "Count\tAverage\tSD\tCV\tA1C\n";

  my $days_from = sprintf("datetime('now' , '-%d days')",$num_days);
  my $days_to   = sprintf("datetime('now' , '-%d days')",0);
  my $sql="select bg from bgtable where timestamp between $days_from and $days_to";
  @bgData = read_db_data($sql);
  $bgCount = @bgData;
  if ( $bgCount >= $minBGcount) {
    my $bgAve = sprintf( "%.02f", &average(\@bgData) );
    my $bgStd = sprintf( "%.02f", &stdev(\@bgData) );
    my $bgCof = sprintf( "%.02f", &cofvar(\@bgData) );
    my $a1c =   sprintf( "%.02f", &a1c($bgAve) );
    print "$bgCount\t$bgAve\t$bgStd\t$bgCof\t$a1c\n";
  }
  else {
    print "$bgCount\t<SAMPLE_SIZE_TOO_SMALL>\n";
  }
}

sub open_db {
  # open db
  print "Opening DB: $db_file\n";
  $db_handle = DBI->connect("dbi:SQLite:dbname=$db_file", $db_user, $db_password, {
    PrintError       => 0,
    RaiseError       => 0,
    AutoCommit       => 0,
    FetchHashKeyName => 'NAME_lc',
  }) or die $DBI::errstr;
}

# 
# ----------------------------- main ----------------------------
#

# parse commandline options.
GetOptions( "import=s"  => \$fname, 
            "type=s"    => \$type,
            "debug=i"   => \$debug,            
            "db=s"      => \$db_file,
            "months=i"  => \$months,
            "weeks=i"   => \$weeks,
            "days=i"    => \$days,
            "export=s"  => \$export_fname,
            "version"   => \&print_version,
            "help"      => \&usage)
or die ("Error in command line arguments: \n");

# open the DB
open_db();

# if export requested, export & quit
if ( defined $export_fname ) {
  print "Exportting data from sqlite DB to CSV file: $export_fname\n";
  export_data();
  exit;
}

if ( defined $fname ) {
  # do import
  if ( ! -f $fname ) {
    print "$fname not found for import!\n";
  }
  if ( $type eq "libre" ) {
    print "Importing 'Libre Freestyle' data from file: $fname\n";
    print "Data type: $type\n";
    import_libre_data();
    exit;
  }
  elsif ( $type eq "libreview" ) {
    print "Importing 'LibreView' cloud export data from file: $fname\n";
    print "Data type: $type\n";
    import_libreview_data();
    exit;
  }
  elsif ( $type eq "liapp" ) {
    print "Importing 'LiApp' data from file: $fname\n";
    print "Data type: $type\n";
    import_liapp_data();
    exit;
  }
  else {
    print "Unknown import type: '$type'\n";
    exit;
  }
}

print "Calculating A1C based on FreeStyle Libre CGM data...\n";

# see if we need to to monthly as well
if ( $months > 0 ) {
  # do monthly for the year specified
  compute_a1c_monthly();
}
elsif ( $weeks > 0) {
  # do weekly for the number of weeks going back
  compute_a1c_weekly();
}
elsif ( $days > 0 ) {
  compute_a1c_days();
}
else {
  # compute for all data
  # note: this may not make sense as data could be years worth and a1c is really last 90days
  compute_a1c_all();
}
