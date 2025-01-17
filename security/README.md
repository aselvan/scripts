# security

### Security, password, encryption related random scripts

- #### /ismalicious.sh
  wrapper over ismalicious.com API and projecthoneyport.org DNSBL to check malicious IP/domain

  **Usage:**
```

  Check IP:
  --------
  arul@lion$ ismalicious.sh -n 222.95.175.237
  ismalicious.sh v25.01.17, 01/17/25 09:43:05 AM 
  Checking reputation of 222.95.175.237 using ismalicious API ...
  {
    "sources": [
      {
        "status": "verified",
        "name": "FireHOL - Blocklist - Firehol Abusers 30d",
        "type": "ip",
        "category": "malware",
        "url": "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_abusers_30d.netset"
      }
    ],
    "type": "IP",
    "value": "222.95.175.237",
    "reputation": {
      "malicious": 1,
      "harmless": 0,
      "suspicious": 0,
      "undetected": 571,
      "timeout": 0
    }
  }
  Checking reputation of 222.95.175.237 using ProjectHoneypot API ...
	  Malicious:    YES [seen as recently as of last 8 day(s)].
	  Threat score: 29/255. [Note: score of 0 is clean]
	  Threat type:  1 [note: 0=searchengine; 1=suspicious, 2=harvester, 4=comment_spammer]

  Check Domain:
  -------------
  arul@lion$ ismalicious.sh -n qouv.fr
  ismalicious.sh v25.01.17, 01/17/25 09:51:33 AM 
  Checking reputation of qouv.fr using ismalicious API ...
  {
    "sources": [
      {
        "status": "verified",
        "name": "Hyder365 - Combined.txt",
        "type": "domain",
        "category": "phishing",
        "url": "https://raw.githubusercontent.com/hyder365/combined-dns-list/master/combined.txt"
      }
    ],
    "type": "DOMAIN",
    "value": "qouv.fr",
    "reputation": {
      "malicious": 1,
      "harmless": 0,
      "suspicious": 0,
      "undetected": 571,
      "timeout": 0
    }
  }

```

- #### /rbl_check.sh
  script to check if an IP is listed on well known RBL (realtime blackhole list) lists

  **Usage:**
```
  arul@lion$ rbl_check.sh -i 222.95.175.237
  rbl_check.sh v23.11.15, 01/17/25 10:13:24 AM 
  Checking 222.95.175.237 against variety of RBL (Realtime Blackhole List)
  222.95.175.237 is LISTED on RBL dnsbl-1.uceprotect.net as 127.0.0.2
  222.95.175.237 is LISTED on RBL dnsbl-2.uceprotect.net as 127.0.0.2
  222.95.175.237 is GOOD on RBL dnsbl-3.uceprotect.net
  222.95.175.237 is LISTED on RBL bl.spamcop.net as 127.0.0.2
  222.95.175.237 is LISTED on RBL zen.spamhaus.org as 127.0.0.4
  222.95.175.237 is GOOD on RBL dnsbl.sorbs.net
  222.95.175.237 is GOOD on RBL bl.tiopan.com
  222.95.175.237 is LISTED on RBL cbl.abuseat.org as 127.0.0.2
  222.95.175.237 is GOOD on RBL dnsbl.njabl.org
  222.95.175.237 is LISTED on RBL b.barracudacentral.org as 127.0.0.2
  222.95.175.237 is LISTED on RBL hostkarma.junkemailfilter.com as 127.0.1.1
  222.95.175.237 is LISTED on RBL truncate.gbudb.net as 127.0.0.2
  222.95.175.237 is GOOD on RBL dnsbl.proxybl.org
```

- #### /certbot_renew.sh
  simple wrapper script certbot renewal of my domains.
  
- #### /clamscan.sh
  wrapper script for clamscan to update clamav signature, urlhaus signature and do scan.
  
- #### /deterministic_pwgen.sh
  Simple wrapper over pwgen to produce deterministic password. You can use this to create a strong password 
  that is never stored anywhere like many password utilities ex: OnePass,Keypass etc and recalled anytime
  as long as you can remember your master passphrase and website, username.

- #### /enc_account.sh 
  Shell script to encrypt sensitive data and store it on google drive

- #### /encrypted_drive.sh
  Shell script to store/retrieve files to/from encrypted folder

- #### /mypass.sh
  simple script to add/search passwords from an encrypted file
  
- #### /oathtool.sh
  simple wrapper over oathtool to keep the secret keys in encrypted form.

- #### /pwned_password.php
  Check if you are using any compromised passwords.

- #### /secret.sh
  convenient wrapper to view/search sensitive data in an encrypted file.

- #### /symantec_vipaccess_key.sh
  extract the secret key from Symantec VIPAccess app.

- #### /vpnsecure
  Configuration file to run openvpn for the VPN service from VPNsecure.me
  
