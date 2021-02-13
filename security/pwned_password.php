#!/usr/bin/php
<?php
/**
* Simple method to use the API from  
* https://www.troyhunt.com/ive-just-launched-pwned-passwords-version-2/
* 
* Jim Westergren --- original author
* Arul Selvan    --- added main driver, and additional details -- Feb 25, 2018
*
* how to run: 
*   php pwned_password.php
*/

function checkPawnedPasswords(string $password) : int {
    $sha1 = strtoupper(sha1($password));
    $first_five_digit=substr($sha1,0,5);
    echo "[INFO] sending partial hash ($first_five_digit) of your full hash ($sha1) to troyhunt.com to check\n";
    $data = file_get_contents('https://api.pwnedpasswords.com/range/'.$first_five_digit);

    if (strpos($data, substr($sha1, 5))) {
        $data = explode(substr($sha1, 5).':', $data);
        $count = (int) $data[1];
    }
    return $count ?? 0;
}

# prompt for password, hide screen.
echo "Enter your password to check: ";
system('stty -echo');
trim(fscanf(STDIN, "%s\n", $password));
system('stty echo');
echo "\n[INFO] don't worry, will only use first 5 char of your password hash\n";

# check the password against Troy's DB
$count = checkPawnedPasswords($password);
if ($count > 0) {
  echo "[WARN] Oops, your password is found $count times!\n";
}
else {
  echo "[INFO] Good news, your password is not found\n";
}
