# rspamd configuration:
{ config, lib, pkgs, ... }:
let
  cfg = config.mailrc;
in
{
  ###### Implementation
  config = lib.mkIf cfg.enable {

    ############################################################################
    # Use a Redis cache:
    services.redis = {
      enable = lib.mkForce true;
      bind = lib.mkDefault "127.0.0.1";
      unixSocket = lib.mkDefault "/run/redis/redis.sock";
    };

    ############################################################################
    # rspamd:
    services.rspamd = {
      enable = true;
      debug = false;

      workers = {
        controller = {
          enable = true;
        };

        normal = {
          enable = true;
        };

        rspamd_proxy = {
          enable = true;
          type = "rspamd_proxy";
          bindSockets = [
            {
              mode = "0660";
              socket = "/run/rspamd/rspamd-milter.sock";
              owner = config.services.rspamd.user;
              group = cfg.postfixGroup;
            }
            {
              socket = "127.0.0.1:11332";
            }
          ];
          extraConfig = ''
            upstream "local" {
              default = yes; # Self-scan upstreams are always default
              self_scan = yes; # Enable self-scan
            }
          '';
        };

        fuzzy = {
          enable = true;
          type = "fuzzy";
          bindSockets = [ "127.0.0.1:11335" ];
          extraConfig = ''
            hashfile = "$DBDIR/fuzzy.db"
            expire = 90d;
            allow_update = ["127.0.0.1", "::1"];
          '';
        };
      };

      locals."redis.conf".text = ''
        # Redis caching:
        servers = "127.0.0.1:${toString config.services.redis.port}";
        expand_keys = yes;
      '';

      locals."milter_headers.conf".text = ''
        extended_spam_headers = true;
        remove_upstream_spam_flag = true;
        skip_authenticated = false;
        skip_local = false;
      '';

      # https://rspamd.com/doc/tutorials/writing_rules.html
      locals."groups.conf".text = ''
        symbols = {
          "HAS_PHPMAILER_SIG" {
            weight = 10.0;
          }
        }
      '';

      # https://rspamd.com/doc/tutorials/writing_rules.html
      overrides."actions.conf".text = ''
        reject = 15.0;
        add_header = 5;
        greylist = 3;
      '';
    };

    systemd.services.rspamd = {
      wants = [ "redis.service" ];
      after = [ "redis.service" ];
    };
  };
}
