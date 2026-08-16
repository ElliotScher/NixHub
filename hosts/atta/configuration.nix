{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific system overrides for atta go here.
  # networking.hostName is set automatically from this directory's name.
  # Anything in ../../common/configuration.nix marked with lib.mkDefault can
  # be overridden with a plain assignment.

  # No physical swap is configured on this host (see hardware-configuration.nix),
  # which leaves systemd-oomd's memory-pressure handling degraded and lets the
  # system stall hard under memory pressure before the kernel OOM killer finally
  # steps in. zram gives it fast compressed swap to work with.
  zramSwap.enable = true;

  # GlobalProtect VPN client (gpclient/gpgui), needed to connect to work VPN.
  services.ayatana-indicators.enable = true;
  environment.systemPackages = [
    pkgs.qemu
    pkgs.virt-viewer
    # nixpkgs pins osinfo-db to a snapshot date, so new distro releases (e.g.
    # Ubuntu 26.04) are missing from virt-manager's OS dropdown until it's
    # refreshed: `osinfo-db-import --user --latest`.
    pkgs.osinfo-db-tools
    inputs.globalprotect-openconnect.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # KVM/QEMU virtualisation via libvirtd, managed through virt-manager (GUI)
  # or virsh/virt-install (CLI).
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.users.elliotscher.extraGroups = [ "libvirtd" ];
}
