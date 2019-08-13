<?php
#
# Simple check to see if the underlying ssl lib supports tls1.2
#
# Author:  Arul Selvan
# Version: Jan 11, 2017
#

$ssl_check_url="https://www.howsmyssl.com/a/check";

$ch = curl_init($ssl_check_url);

#curl_setopt($ch, CURLOPT_SSL_ENABLE_ALPN, false);
#curl_setopt($ch, CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1_2);
curl_setopt($ch, CURLOPT_SSLVERSION, 6);
curl_setopt($ch, CURLOPT_SSL_CIPHER_LIST, 'ECDHE-RSA-AES128-SHA256');
curl_setopt($ch, CURLOPT_VERBOSE, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$res= curl_exec($ch);
curl_close($ch);

$tlsVer = json_decode($res, true);
echo "\nTSL version: " . ( $tlsVer['tls_version'] ? $tlsVer['tls_version'] : 'no TLS support' ) . "\n";
echo "Rating:      " . ( $tlsVer['rating'] ? $tlsVer['rating'] : 'n/a' ) . "\n";
echo "\n"

?>
