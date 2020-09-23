require "fileinto";
require "imap4flags";
require "mailbox";

if header :contains "X-Spam" "Yes" {
  setflag "\\seen";
  fileinto :create "Junk";
  stop;
}
