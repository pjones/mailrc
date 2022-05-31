{ mkSieveDerivation
, mblaze
}:
mkSieveDerivation {
  name = "mailrc-sieve-user";
  src = ../sieve/user;

  path = [
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
