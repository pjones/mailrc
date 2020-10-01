{ config, pkgs, lib, ... }:
let
  cfg = config.mailrc.muchsync;
  path = lib.makeBinPath config.mailrc.notmuch.packages;

  script = pkgs.writeShellScript "muchsync" (
    ''
      set -eu
      export PATH=${path}:$PATH
    ''
    + lib.concatMapStringsSep "\n"
      (remote: ''
        muchsync -F ${lib.escapeShellArg remote} -F
      '')
      cfg.remotes
  );
in
{
  options.mailrc.muchsync = {
    enable = lib.mkEnableOption "Muchsync with remote mail database";

    frequency = lib.mkOption {
      type = lib.types.str;
      default = "*:0/5";
      description = ''
        A systemd OnCalendar value to control how often to sync.
      '';
    };

    remotes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of host names to sync with.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.remotes != [ ]) {
    systemd.user.services.muchsync = {
      Unit.Description = "muchsync sync service";
      Unit.After = [ "network.target" ];
      Service = {
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        ExecStart = toString script;
      };
    };
    systemd.user.timers.muchsync = {
      Unit.Description = "muchsync periodic sync";
      Install.WantedBy = [ "timers.target" ];
      Timer = {
        Unit = "muchsync.service";
        OnCalendar = cfg.frequency;
        Persistent = true;
      };
    };
  };
}
