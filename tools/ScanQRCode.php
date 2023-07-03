#!/usr/bin/env php
<?php
#
# ScanQRCode.php --- Wrapper php class to scan the qrcode image.
#
# This php code reads the QRCode image as commandline argument, scan and print the
# the QR-Code element using zbarimg so you had to have that in the path for this
# code to work.
#
# PreReq: zbarimage must be installed as shown below.
#         Linux: 'apt-get install zbar-tools'
#         MacOS: 'brew install zbar'
#
# Author:  Arul Selvan
# Version: Jul 3, 2023
#

class ScanQRCode {
  protected $qr_image;

  protected $validFiles = [
    'application/pdf',  
    'image/png',
    'image/jpeg',
    'image/svg+xml',
    'image/gif',
  ];

  public function __construct($image) {
    $this->qr_image = $image;

    # validate file exist & is the right type
    if (! file_exists($this->qr_image)) {
      throw new Exception ("file '" . $this->qr_image . "' does not exists!");
    }

    $mimeType = mime_content_type($this->qr_image);

    if (! in_array($mimeType, $this->validFiles)) {
      throw new Exception("image file mimeType: " . $mimeType . " is not valid!");
    }
  }

  public function scan() {
    $output=null;
    $rc=null;

    exec("zbarimg -q ". $this->qr_image, $output, $rc);
    if ( $rc != 0 ) {
      throw new Exception("zbarimage scan failed for '". $this->qr_image . "' error code='" . $rc);
    }
    return implode(" ",$output);
  }
}

# --------- Main ---------------

try {
  $qr_code = new ScanQRCode($argv[1]);
  echo $qr_code->scan(), "\n";
} 
catch (Exception $e) {
  echo "ERROR: " .$e->getMessage() . "\n";
}

?>
