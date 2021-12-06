{ config, pkgs, lib, ... }:
let
  cfg = config.mailrc;
  opendkim = cfg.opendkim;

  # Optionally permit authenticated clients:
  permit_auth =
    if cfg.mode == "primary"
    then "permit_sasl_authenticated"
    else null;

  # Postfix comma-delimited lists:
  postfix_list = xs:
    lib.concatStringsSep "," (lib.filter (x: x != null) xs);

  # Restrictions that the Postfix SMTP server applies in the context
  # of a client HELO command.
  smtpd_helo_restrictions = postfix_list [
    permit_auth
    "reject_invalid_helo_hostname"
    "permit"
  ];

  # Restrictions that the Postfix SMTP server applies in the context
  # of a client connection request.
  smtpd_client_restrictions = postfix_list [
    "permit_mynetworks"
    permit_auth
    "reject_unauth_pipelining"
    "reject_rbl_client zen.spamhaus.org"
    "reject_rhsbl_reverse_client dbl.spamhaus.org"
    "permit"
  ];

  # Access restrictions for mail relay control that the Postfix SMTP
  # server applies in the context of the RCPT TO command, before
  # smtpd_recipient_restrictions.
  smtpd_relay_restrictions = postfix_list [
    "permit_mynetworks"
    permit_auth
    "reject_unauth_destination"
  ];

  # Restrictions that the Postfix SMTP server applies in the context
  # of a client RCPT TO command, after smtpd_relay_restrictions.
  smtpd_recipient_restrictions = postfix_list [
    "reject_non_fqdn_recipient"
    "permit_mynetworks"
    permit_auth
    (if cfg.mode == "primary"
    then "permit_auth_destination"
    else "permit_mx_backup")
    "reject"
  ];

  # Restrictions that the Postfix SMTP server applies in the context
  # of a client MAIL FROM command.
  smtpd_sender_restrictions = postfix_list [
    "permit_mynetworks"
    (if cfg.mode == "primary"
    then "reject_sender_login_mismatch"
    else "reject_unauthenticated_sender_login_mismatch")
    "reject_unlisted_sender"
    "reject_non_fqdn_sender"
    "reject_unknown_sender_domain"
    "check_sender_access hash:${cfg.postfixBaseDir}/etc/senderaccess"
    "reject_rhsbl_sender dbl.spamhaus.org"
    "permit"
  ];

in
''
  # Backwards compatibility for the configuration syntax:
  compatibility_level=3.6

  # Directories and Users
  queue_directory = ${cfg.postfixBaseDir}/queue
  command_directory = ${pkgs.postfix}/sbin
  daemon_directory = ${pkgs.postfix}/libexec/postfix
  mail_owner = ${cfg.postfixUser}
  default_privs = nobody

  # Identity Settings
  myhostname = ${cfg.externalServerName}
  mydomain = ${cfg.primaryDomain}
  myorigin = $myhostname
  mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 ${lib.concatStringsSep " " cfg.trustedRelayServers}
  inet_interfaces = all

  # Restrictions and Spam Blocking
  smtpd_sender_login_maps = hash:${cfg.postfixBaseDir}/etc/sendermap
  smtpd_helo_required = yes
  smtpd_helo_restrictions = ${smtpd_helo_restrictions}
  smtpd_client_restrictions = ${smtpd_client_restrictions}
  smtpd_recipient_restrictions = ${smtpd_recipient_restrictions}
  smtpd_sender_restrictions = ${smtpd_sender_restrictions}
  smtpd_relay_restrictions = ${smtpd_relay_restrictions}

  # Database and File Mappings
  alias_maps = hash:${cfg.postfixBaseDir}/etc/aliases
  alias_database = hash:${cfg.postfixBaseDir}/etc/aliases

  # Mail Filtering and Signing (DKIM, SPAM, etc.):
  #
  # Below, the `{auth_type}' macro is mandatory for OpenDKIM to work correctly.
  #
  milter_protocol = 6
  milter_default_action = tempfail
  milter_mail_macros = i {mail_addr} {client_addr} {client_name} {auth_authen} {auth_type}
  smtpd_milters = inet:127.0.0.1:${toString cfg.rspamdMilterPort} inet:127.0.0.1:${toString opendkim.port}
  non_smtpd_milters = inet:127.0.0.1:${toString cfg.rspamdMilterPort} inet:127.0.0.1:${toString opendkim.port}

  # Other Random Settings
  smtpd_banner = $myhostname ESMTP $mail_name
  recipient_delimiter = +
  biff = no
  append_dot_mydomain = no
  readme_directory = no
  maximal_queue_lifetime = 10d
  message_size_limit = 104857600

'' + lib.optionalString (cfg.mode == "primary") ''

  # Local Delivery
  mydestination = hash:${cfg.postfixBaseDir}/etc/hostnames
  mailbox_transport = lmtp:unix:${cfg.postfixBaseDir}/${cfg.dovecotLMTPSocket}
  mailbox_size_limit = 0
  home_mailbox = mail/

  # Authentication:
  smtpd_sasl_auth_enable = yes
  smtpd_sasl_authenticated_header = yes
  smtpd_sasl_local_domain = $myhostname
  smtpd_sasl_path = ${cfg.postfixBaseDir}/${cfg.dovecotAuthSocket}
  smtpd_sasl_security_options = noanonymous
  smtpd_sasl_type = dovecot

  # TLS parameters
  smtp_tls_session_cache_database = btree:${cfg.postfixBaseDir}/cache/smtp_scache
  smtp_use_tls = yes
  smtpd_tls_auth_only = yes
  smtpd_tls_cert_file = ${cfg.sslServerCertFile}
  smtpd_tls_key_file  = ${cfg.sslServerKeyFile}
  smtpd_tls_mandatory_ciphers = medium
  # FIXME: After Postfix 3.6 is in nixpkgs replace this with >=TLSv1.2
  # http://www.postfix.org/postconf.5.html#smtpd_tls_mandatory_protocols
  smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
  smtpd_tls_received_header = yes
  smtpd_tls_session_cache_database = btree:${cfg.postfixBaseDir}/cache/smtpd_scache
  smtpd_use_tls = yes
  tls_random_source = dev:/dev/urandom
  broken_sasl_auth_clients = yes

  # Virtual Hosting
  virtual_mailbox_base = ${cfg.postfixBaseDir}/vhosts
  virtual_mailbox_domains = hash:${cfg.postfixBaseDir}/etc/virtualhosts
  virtual_mailbox_maps = hash:${cfg.postfixBaseDir}/etc/virtualdirs
  virtual_alias_maps = hash:${cfg.postfixBaseDir}/etc/virtualaliases
  virtual_minimum_uid = 5000
  virtual_uid_maps = static:${toString cfg.virtualUID}
  virtual_gid_maps = static:${toString cfg.virtualGID}
  virtual_transport = lmtp:unix:${cfg.postfixBaseDir}/${cfg.dovecotLMTPSocket}

'' + lib.optionalString (cfg.mode == "secondary") ''
  # No local delivery:
  mydestination = localhost

  # Relay to another server:
  permit_mx_backup_networks = hash:${cfg.postfixBaseDir}/etc/transport
  relay_domains = hash:${cfg.postfixBaseDir}/etc/transport
  transport_maps = hash:${cfg.postfixBaseDir}/etc/transport
  relay_recipient_maps = hash:${cfg.postfixBaseDir}/etc/relayrecipients
''
