require ["variables", "regex", "fileinto", "mailbox", "vacation"];
require "vnd.dovecot.pipe";

if header :matches "Subject" "*" {
  set "origsub" "${1}";
}

if header :regex ["to", "cc"] "^(root|sysadmin|webadmin|postmaster)@" {
  # Messages that need to go to a "root" mailbox.
  pipe "notmuch-insert.sh" [ "root" ];

} elsif header :regex ["to", "cc"] "^(domains)@" {
  # Messages about domain names, DNS, etc.
  pipe "notmuch-insert.sh" [ "misc" ];

} elsif header :regex "to" "^<?(travel)@" {
  # Messages from travel sites.  The `<' above is to cover hotels.com
  # which sends emails to <travel@pmade.com> and that seems to trip up
  # the sieve regex engine.
  pipe "notmuch-insert.sh" [ "Travel" ];

} elsif header :regex "from" "@(hotels.com|southwest.com|carrentals.com|theparkingspot.com)" {
  # Messages about travel plans:
  pipe "notmuch-insert.sh" [ "Travel" ];

} elsif header :regex "from" "gitlab-no-reply@" {
  # Treat GitLab comments, assignments, etc as a mailing list.
  pipe "notmuch-insert.sh" [ "mlists" ];

} elsif header :regex ["to", "cc"] "@(mynewt)\\." {
  # Mailing lists that only have an address.
  pipe "notmuch-insert.sh" [ "mlists" ];

} elsif header :matches "list-id" "* <*" {
  # Mailing lists that have a name.
  pipe "notmuch-insert.sh" [ "mlists" ];
} else {
  # Everything else goes into the Inbox:
  pipe "notmuch-insert.sh" [ "INBOX" ];
}
