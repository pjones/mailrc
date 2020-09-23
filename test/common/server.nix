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
  services.redis.logLevel = "debug";

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
    externalServerName = "test.example.com";
    primaryDomain = externalServerName;
    officialName = externalServerName;
    primaryMailServer = externalServerName;

    systemUsers.${user.systemUser} = {
      password = user.hashed;
      home = config.users.users.${user.systemUser}.home;
      uid = config.users.users.${user.systemUser}.uid;
      gid = config.users.groups.users.gid;
    };

    virtualhosts = {
      "vhost.example.com" = {
        accounts.${user.username}.password = user.hashed;
      };
    };

    opendkim = {
      enable = true;

      hosts.test = {
        addressWildcards = [ "*@vhost.example.com" ];
        signingDomain = "vhost.example.com";
        selector = "xxxxxxxxx";
        privateKey = ''
          -----BEGIN RSA PRIVATE KEY-----
          MIICXAIBAAKBgQDOFvBv5soKJhmJOptOg4sWU//HH4i93nn6clZYG2p6mOOl3mlD
          P0sOW+N4P00AtZmmOk/GuHNSbwdthqQwWhd/sGvmRuszqgDvkzJ9ERiwKHC8OJD3
          OCxej/3IUkDiRyjTZaj+R0+X1FtvjDwhS3zjKSyefY1MyY7dt6NgfTNEbwIDAQAB
          AoGAXbz/VdailSUpPkri8z5P2DMSxw5n0vzLfIffECpAL001Vm+ob0btq7VN7JbW
          PnlbTsl9GcUx5w/LUB0Kt1dzEfY+W9162vdnqEuGsl1BoMgMcEA25rXRHaQl/v9Z
          QkuCD1iq1nZ7ozkaZmUWrQsLcRoHISEchNeLdHQ6ZmXM+BkCQQD9w4cDbnaFxxKU
          ILbcVrZESGP7704yy4k7eKXhlkPtL2Gw8nf41/Rm8/gqbWlZAPqu/a4A2vLgKueP
          WofjHxd9AkEAz+fcwvhXnJ/kMzuq4SLmbMyuqTVZUW9nOsa8sep9m31BEwiU+w0W
          52rR6aS4177Q6GH6AlZ1vH1kAmMNJD+HWwJAdkO81YWSqTAo4W4JqtCiq1oNdumF
          STkAYP4OWP8d8xlE7yFhdlC275A+FQ/erAM/0XQatv1TedOlDXNEpz3jRQJAfpRf
          P0FuLgjXKi4wyqOyARnZWWIGwGMASbPIHNZ0pR9saEc4VWVRxZGuvf6xH4GotWM5
          kQTM5/a71gwyaxhWswJBAKM4weSsMROTMAlWaZwqwKy/5yqV6KUJB+qgFHfEYM1f
          xuy1bOpDFDHe9IJ11pJTop+5VG6ZyXwYRQDPWJNJep8=
          -----END RSA PRIVATE KEY-----
        '';
      };
    };
  };
}
