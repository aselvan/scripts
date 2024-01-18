#!/usr/bin/env php
<?php
/**
* Simple method to use the API from  
*  https://haveibeenpwned.com/API/v3#PwnedPasswords
* 
* Jim Westergren --- original author
* Arul Selvan    --- added main driver, and additional details -- Feb 25, 2018
*
* PreReq: Need php to run this script. MacOS and Linux natively includes php but if you 
*         are using windows, install php)
*
* How to run:
*   Open a command shell and execute the following (on MacOS or Linux no need for php in front)
*
*   php pwned_password.php 
*/
$version="v2018.02.25";

function checkPawnedPasswords(string $password) : int {
    $sha1 = strtoupper(sha1($password));
    $first_five_digit=substr($sha1,0,5);
    echo "Sending partial hash ($first_five_digit) of your full hash ($sha1) to pwnedpasswords.com ...\n";
    $data = file_get_contents('https://api.pwnedpasswords.com/range/'.$first_five_digit);

    if (strpos($data, substr($sha1, 5))) {
        $data = explode(substr($sha1, 5).':', $data);
        $count = (int) $data[1];
    }
    return $count ?? 0;
}

# prompt for password, hide screen.
$name=basename($argv[0], '.php');
echo "$name $version\n";
echo "Don't panic, sending ONLY first 5 char of your password hash (not password itself) to pwnedpasswords.com\n";
echo "Enter your password to check: ";
system('stty -echo');
trim(fscanf(STDIN, "%s\n", $password));
system('stty echo');

# check the password against Troy's DB
echo "\nChecking your password ...\n";
$count = checkPawnedPasswords($password);
if ($count > 0) {
  echo "### WARNING ### Your password is FOUND $count times!\n";
}
else {
  echo "### CONGRATS ### your password is NOT found!\n";
}
