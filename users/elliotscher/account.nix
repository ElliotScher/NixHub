{ config, pkgs, lib, inputs, ... }:

{
  users.users.elliotscher = {
    isNormalUser = lib.mkDefault true;
    description = lib.mkDefault "Elliot Scher";

    # NOTE: extraGroups and packages are not wrapped in mkDefault - both are
    # lists, so hosts can add to them with their own
    # `users.users.elliotscher.extraGroups = [ ... ];` /
    # `users.users.elliotscher.packages = with pkgs; [ ... ];`, which
    # concatenates rather than conflicts.
    extraGroups = [ "networkmanager" "wheel" ];

    packages = with pkgs; [
      git
      git-lfs
      gh
      libreoffice-qt
      hunspell
      hunspellDicts.en_US
      inputs.antigravity-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      mpv
      tmux
      proton-vpn

      brave
      google-chrome

      slack
      discord

      zotero

      spotify

      jetbrains-toolbox
      jetbrains.clion
      jetbrains.idea
      jetbrains.pycharm
      jetbrains.webstorm

      gnomeExtensions.dash-to-dock
      gnomeExtensions.appindicator
      gnomeExtensions.gsconnect

      # FRC packages (from local frc-nix flake)
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.advantagescope
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.pathplanner
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.sysid
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.glass
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.elastic-dashboard
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.choreo
      inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.wpilib-utility
    ];
  };
}
