{ mkSieveDerivation
, notmuch
, mblaze
}:
mkSieveDerivation {
  name = "mailrc-sieve-user";
  src = ../sieve/user;

  path = [
    notmuch
    mblaze
  ];

  extensions = [
    "+imapsieve"
    "+vnd.dovecot.environment"
    "+vnd.dovecot.pipe"
    "+vnd.dovecot.filter"
  ];

  plugins = [
    "sieve_imapsieve"
    "sieve_extprograms"
  ];
}
