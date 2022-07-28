#!/usr/local/bin/php

<?php
#
# Sample code to get elapsed duraion from a past date.
#
# Author:  Arul Selvan
# Version: Jul 28, 2022
#

$start_date_string="4/22/2022";

# get a past date
echo "Enter past date [$start_date_string]:  ";
trim(fscanf(STDIN, "%s\n", $start_date_string));

$cur_date = new DateTime();
$cur_date_string=$cur_date->format('Y-m-d');
$start_date = new DateTime($start_date_string);
printf ("%s\n","Difference between $start_date_string and now ($cur_date_string) is ... ");
$interval = $start_date->diff($cur_date);
printf ("Total Days: %s\n", $interval->format('%a'));
printf ("Total YMDHMS: %s\n",$interval->format('%y yrs, %m months, %d days, %h hours, %i minutes, %s seconds'));

