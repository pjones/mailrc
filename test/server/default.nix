{ pkgs }:
let
  user = import ../common/user.nix;

  tests = pkgs.callPackage ./tests.nix {
    inherit (user) username password domain;
  };

in
pkgs.nixosTest {
  name = "mailrc-server-test";

  nodes.machine = { ... }: {
    imports = [ ../common/server.nix ];
    environment.systemPackages = [ tests pkgs.curl ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("postfix.service")
    machine.wait_for_unit("opendkim.service")
    machine.wait_for_unit("redis-rspamd.service")
    machine.wait_for_unit("rspamd.service")
    machine.wait_for_open_port(11332)

    machine.wait_for_unit("dovecot2.service")
    machine.succeed("test -e /var/lib/dovecot/passwords")

    machine.succeed("test-smtp ${user.username}@${user.domain}")
    machine.succeed("test-smtp ${user.systemUser}@${user.systemDomain}")
    machine.succeed("test-smtp ${user.systemUser}+foobar@${user.systemDomain}")

    machine.wait_until_fails('[ "$(postqueue -p)" != "Mail queue is empty" ]')
    machine.fail("journalctl -u postfix | grep -i error >&2")
    # machine.fail("journalctl -u postfix | grep -i warning >&2")

    machine.succeed("test-imap")
    machine.succeed("test $(test-new ${user.username}) -gt 0")
    machine.succeed("test $(test-new ${user.systemUser}) -gt 0")
    machine.succeed("test $(test-new ${user.systemUser} .subs) -gt 0")

    machine.succeed("curl --silent http://localhost:9166/metrics >&2")
    machine.succeed("curl --silent http://localhost:9154/metrics >&2")
  '';
}
