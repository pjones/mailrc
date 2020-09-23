{ config, pkgs, ... }:

{
  ############################################################################
  # Push postfix tools into the system PATH.
  environment.systemPackages = with pkgs; [
    postfix
  ];
}
