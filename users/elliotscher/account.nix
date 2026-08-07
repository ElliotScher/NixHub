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
      # jetbrains.clion is wrapped below: its bundled C/C++ tooling (ninja,
      # clangd, gdb, lldb, clang-tidy) ships prelinked against gcc's libgcc
      # RPATH only, missing libstdc++.so.6, so those subprocesses fail to
      # launch ("full functionality will be available after restart").
      (symlinkJoin {
        name = "clion";
        paths = [ jetbrains.clion ];
        buildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/clion \
            --prefix LD_LIBRARY_PATH : "${stdenv.cc.cc.lib}/lib"
        '';
      })
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
