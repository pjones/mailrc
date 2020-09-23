# Important Changes

## 2020-09-23

Improved security by moving sensitive information out of the Nix store:

  * Account passwords can no longer be given as strings and instead
    must be given as files.  Therefore the account option `password`
    has been replaced with `passwordFile`.

  * Usernames used during authentication have been changed so the only
    form allowed is `local@domain`.  In other words, it's no longer
    possible to authenticate with the local part only.

  * The `localPart` account option has been removed.

  * The OpenDKIM host option `privateKey` has been replaced with
    `privateKeyFile`.
