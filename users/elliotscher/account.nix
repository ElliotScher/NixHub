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
    ];
  };
}
