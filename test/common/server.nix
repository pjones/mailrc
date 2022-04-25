# A fully configured mail server.
{ config, pkgs, lib, ... }:
let
  user = import ./user.nix;
in
{
  imports = [
    ../../nixos
  ];

  networking = {
    hostName = "machine";
    domain = "example.com";
  };

  virtualisation.memorySize = 1024;
  services.redis.servers.rspamd.logLevel = "debug";

  security.acme = {
    acceptTerms = true;
    email = "test@example.com";
    server = "https://127.0.0.1:1/directory";
  };

  users.users.${user.systemUser} = {
    createHome = true;
    isNormalUser = true;
    password = "password";
    uid = 1001;
    group = "users";
  };

  mailrc = rec {
    enable = true;
    externalServerName = user.systemDomain;
    primaryDomain = externalServerName;
    officialName = externalServerName;
    primaryMailServer = externalServerName;

    systemUsers.${user.systemUser} = {
      passwordFile = pkgs.writeText "passwd" user.hashed;
      home = config.users.users.${user.systemUser}.home;
      uid = config.users.users.${user.systemUser}.uid;
      gid = config.users.groups.users.gid;
    };

    virtualhosts = {
      "vhost.example.com" = {
        accounts.${user.username}.passwordFile =
          pkgs.writeText "passwd" user.hashed;
      };
    };

    opendkim = {
      enable = true;

      hosts.test = {
        addressWildcards = [ "*@vhost.example.com" ];
        signingDomain = "vhost.example.com";
        selector = "default";
        privateKeyFile = "/run/opendkim/default.private";
      };
    };
  };

  systemd.services.opendkim.preStart = ''
    ${pkgs.opendkim}/bin/opendkim-genkey \
      -s default -d vhost.example.com \
      --directory=/run/opendkim
  '';
}
