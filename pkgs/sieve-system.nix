##############################################################################
# A special package that holds sieve files for learning spam/ham
# when mail is moved to/from the Junk folder:
{ mkSieveDerivation
, rspamd
}:
mkSieveDerivation {
  name = "mailrc-sieve-system";
  src = ../sieve/system;
  path = [ rspamd ];

  extensions = [
    "+imapsieve"
    "+vnd.dovecot.pipe"
  ];

  plugins = [
    "sieve_imapsieve"
    "sieve_extprograms"
  ];
}
