{ pkgs, home-manager }:
{
  server = import ./server { inherit pkgs; };
  client = import ./client { inherit pkgs home-manager; };
}
