require
  [ "imap4flags"
  , "regex"
  , "vacation"
  , "vnd.dovecot.pipe"
  , "fileinto"
  , "mailbox"
  ];

# auto-confirm@amazon.com
# account-update@amazon.com
# shipment-tracking@amazon.com

################################################################################
if allof
  ( address :is :localpart "to" "postmaster"
  , header :regex "subject" "^Report domain:"
  )
{
  # FIXME: At some point these should be piped to a script that will
  # extract the DMARC reports and load them into a database.
  setflag "\\seen";
  fileinto :create "root";
}

################################################################################
elsif address :is :localpart ["to", "cc"]
  [ "root"
  , "sysadmin"
  , "webadmin"
  , "postmaster"
  ]
{
  # Messages that need to go to a "root" mailbox.
  fileinto :create "root";
}

################################################################################
elsif address :is :localpart ["to", "cc"] "domains" {
  # Messages about domain names, DNS, etc.
  fileinto :create "misc";
}

################################################################################
elsif anyof
  ( address :is :localpart "to" "travel"
  , address :is :domain "from"
      [ "hotels.com"
      , "southwest.com"
      , "carrentals.com"
      , "theparkingspot.com"
      ]
  )
{
  # Messages about travel plans:
  fileinto :create "Travel";
}

################################################################################
elsif anyof
  ( address :is :localpart ["to", "cc"] "mlists"
  , header :matches "list-id" "* <*"
  )
{
  # Mailing lists that have a name.
  fileinto :create "mlists";
}
