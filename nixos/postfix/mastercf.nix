{ config, pkgs, lib, ... }:
let
  cfg = config.mailrc;
in
''
  # ==========================================================================
  # service type  private unpriv  chroot  wakeup  maxproc command + args
  #               (yes)   (yes)   (yes)   (never) (100)
  # ==========================================================================
  smtp      inet  n       -       n       -       -       smtpd
  pickup    fifo  n       -       n       60      1       pickup
  cleanup   unix  n       -       n       -       0       cleanup
  qmgr      fifo  n       -       n       300     1       qmgr
  tlsmgr    unix  -       -       n       1000?   1       tlsmgr
  rewrite   unix  -       -       n       -       -       trivial-rewrite
  bounce    unix  -       -       n       -       0       bounce
  defer     unix  -       -       n       -       0       bounce
  trace     unix  -       -       n       -       0       bounce
  verify    unix  -       -       n       -       1       verify
  flush     unix  n       -       n       1000?   0       flush
  proxymap  unix  -       -       n       -       -       proxymap
  proxywrite unix -       -       n       -       1       proxymap
  smtp      unix  -       -       n       -       -       smtp
  relay     unix  -       -       n       -       -       smtp
    -o smtp_fallback_relay=
  showq     unix  n       -       n       -       -       showq
  error     unix  -       -       n       -       -       error
  retry     unix  -       -       n       -       -       error
  discard   unix  -       -       n       -       -       discard
  local     unix  -       n       n       -       -       local
  virtual   unix  -       n       n       -       -       virtual
  lmtp      unix  -       -       n       -       -       lmtp
  anvil     unix  -       -       n       -       1       anvil
  scache    unix  -       -       n       -       1       scache

'' + lib.optionalString (cfg.mode == "primary") ''
  465       inet  n       -       n       -       -       smtpd
   -o smtpd_tls_wrappermode=yes
   -o smtpd_sasl_auth_enable=yes
''
