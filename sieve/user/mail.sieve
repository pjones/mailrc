require
  [ "imap4flags"
  , "regex"
  , "vacation"
  , "vnd.dovecot.pipe"
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
  pipe "notmuch-insert.sh" [ "root", "-unread" ];
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
  pipe "notmuch-insert.sh" [ "root" ];
}

################################################################################
elsif address :is :localpart ["to", "cc"] "domains" {
  # Messages about domain names, DNS, etc.
  pipe "notmuch-insert.sh" [ "misc" ];
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
  pipe "notmuch-insert.sh" [ "Travel" ];
}

################################################################################
elsif anyof
  ( address :is :localpart ["to", "cc"] "mlists"
  , header :matches "list-id" "* <*"
  )
{
  # Mailing lists that have a name.
  pipe "notmuch-insert.sh" [ "mlists" ];
}

################################################################################
else {
  # Everything else goes into the Inbox:
  pipe "notmuch-insert.sh" [ "INBOX" ];
}
