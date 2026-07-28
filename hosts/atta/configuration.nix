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
}
