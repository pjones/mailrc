# Important Changes

## 2021-12-06 (NixOS 21.11)

### Postfix (3.6.0 -> 3.6.3)

  * Fixed the `compatibility_level` setting to that it uses one of the
    official levels, namely `3.6`.

### Dovecot (2.3.16 -> 2.3.17)

  * Replaced the prometheus exporter for Dovecot with the built-in
    OpenMetrics exporter.

  * Disabled verbose authentication logging.

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
