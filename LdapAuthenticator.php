<?php

//
// LdapAutheticate.php
// Simple php code to authenticate w/ using LDAP proto to a M$ AD
//
// Author:  Arul Selvan
// Version: Jul 25, 2017
//

class LdapAuthenticator {
  private $AD_SERVER="ldap.yourcompany.com";
  private $handle;

  public function __construct() {
    $this->handle = ldap_connect($this->AD_SERVER);
    if ( ! $this->handle ) {
      // can't connect
      die("ERROR: unable to connect to $AD_SERVER; handle=$this->handle \n");
    }
    ldap_set_option($this->handle, LDAP_OPT_PROTOCOL_VERSION, 3); // Recommended for AD
  }

  public function authenticate($user, $password) {
    if ( ! $user || ! $password ) {
      die("user or password empty!, try with valid user/password\n");
      return;
    }
    try {
      $status = ldap_bind($this->handle, $user, $password);
      if ( ! $status) {
        die("Authentication failed!\n");
      }
      else {
        die("Authentication Success!\n");
      }
    }
    catch (Exception $e) {
      die ("Authenticaion failed: ". $e->getMessage() . "\n");
    }
  }
}

$lda = new LdapAuthenticator();
$lda->authenticate("user", "password");

?>
