# To run this:
#
#   sudo sieve-filter -veWC -u pjones /home/pjones/sieve/archive.sieve Archive
#
# The `Archive' mailbox can be replaced with any other mailbox.
#
# More Info:
#
#   https://mebsd.com/configure-freebsd-servers/dovecot-pigeonhole-sieve-filter-refilter-delivered-email.html
#
require ["variables", "date", "fileinto", "mailbox"];
require "vnd.dovecot.environment";

# Weird way to get the current year.
if currentdate :matches "year" "*" { set "thisyear" "${1}"; }

if date :matches "date" "year" "*" {
  # Try to extract the year from the email date:
  set "year" "${1}";
} else {
  # This should hopefully never happen:
  set "year" "${thisyear}";
}

if string :is "${year}" "${thisyear}" {
  # Keep this year's messages in the original box:
  keep;
} else {
  fileinto :create "${env.vnd.dovecot.default_mailbox}/${year}";
}
