{ pkgs, home-manager }:
let
  user = import ../common/user.nix;
  tests = pkgs.callPackage ./test.nix { };

in
pkgs.nixosTest {
  name = "mailrc-client-tests";

  nodes.machine = { ... }: {
    imports = [
      ../common/server.nix
      home-manager.nixosModules.home-manager
    ];

    environment.systemPackages = [ tests ];

    home-manager.users.${user.systemUser} = { lib, ... }: {
      imports = [
        ../../home
      ];

      home.stateVersion = lib.mkForce "20.09";
      home.username = lib.mkForce user.systemUser;
      home.homeDirectory = lib.mkForce "/home/${user.systemUser}";

      mailrc.enable = true;
      mailrc.sieve.enable = true;

      mailrc.muchsync = {
        enable = true;
        remotes = [ "localhost" ];
      };
    };
  };

  testScript = ''
    start_all()

    machine.stop_job("home-manager-${user.systemUser}.service")
    machine.succeed("mkdir -m 0755 -p /nix/var/nix/{profiles,gcroots}/per-user/${user.systemUser}")
    machine.succeed("chown ${user.systemUser}:root /nix/var/nix/{profiles,gcroots}/per-user/${user.systemUser}")

    machine.start_job("home-manager-${user.systemUser}.service")
    machine.wait_for_unit("home-manager-${user.systemUser}.service")
    machine.succeed("test -L /home/${user.systemUser}/.config/dovecot/sieve/active")

    machine.wait_for_unit("dovecot2.service")
    machine.succeed("test -L /var/lib/dovecot/pipe-bin/notmuch-insert.sh")

    machine.succeed("su - ${user.systemUser} -c mailrc-tests")
    machine.succeed("test -e /home/${user.systemUser}/mail/.notmuch/xapian/position.glass")
  '';
}
