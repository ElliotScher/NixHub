{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific home-manager overrides for elliotscher on atta go here.
  # Anything in ../../../users/elliotscher/home.nix marked with lib.mkDefault can
  # be overridden with a plain assignment.

  # dconf list options aren't merged by mkDefault - overriding requires
  # restating the full common favorite-apps list from
  # ../../../users/elliotscher/home.nix with steam.desktop added, rather than
  # appending to it.
  dconf.settings."org/gnome/shell".favorite-apps = [
    "brave-browser.desktop"
    "google-chrome.desktop"
    "org.gnome.Console.desktop"
    "org.gnome.Nautilus.desktop"
    "slack.desktop"
    "discord.desktop"
    "spotify.desktop"
    "code.desktop"
    "code-frc.desktop"
    "advantagescope.desktop"
    "elastic-dashboard.desktop"
    "choreo.desktop"
    "pathplanner.desktop"
    "clion.desktop"
    "idea.desktop"
    "pycharm.desktop"
    "webstorm.desktop"
    "jetbrains-toolbox.desktop"
    "zotero.desktop"
    "steam.desktop"
    "org.gnome.Settings.desktop"
    "nixos-manual.desktop"
  ];
}
