{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific system overrides for atta go here.
  # networking.hostName is set automatically from this directory's name.
  # Anything in ../../common/configuration.nix marked with lib.mkDefault can
  # be overridden with a plain assignment.

  # Framework Laptop 13, Intel Core Ultra Series 1 mainboard (replaced the
  # 12th-gen Intel board): ambient light sensor, framework-tool, audio
  # tuning, Ethernet expansion card power fix, laptop/SSD defaults.
  imports = [ inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series1 ];

  # Install GRUB to the removable fallback path (\EFI\BOOT\BOOTX64.EFI)
  # instead of registering a boot entry in the mainboard's NVRAM. NVRAM
  # lives on the board, not the disk, so after the mainboard swap the old
  # "NixOS-boot" entry was gone and the disk wasn't bootable until it was
  # fixed by hand. This way every rebuild keeps the fallback copy current,
  # and a future board swap or BIOS reset still boots.
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.efiInstallAsRemovable = true;

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

  # "dialout" grants access to serial/USB TTY devices (/dev/ttyUSB*,
  # /dev/ttyACM*) - needed for ROS2 robotics hardware (microcontrollers,
  # LIDAR, etc). On Ubuntu this is normally `sudo usermod -aG dialout $USER`;
  # on NixOS it has to go through extraGroups + a rebuild instead.
  users.users.elliotscher.extraGroups = [ "libvirtd" "dialout" ];

  # Intel RealSense D405 (RBE 4540 final project camera) udev rules - grants
  # non-root USB access (MODE 0666 + TAG+="uaccess", picked up per-session by
  # systemd-logind, so no extraGroups entry is needed here, unlike dialout
  # above). Without this the camera only opens as root.
  # Nordic nRF udev rules (Micnote's Thingy:53 / nRF5340-DK and J-Link
  # probes) - same uaccess mechanism, so nrfutil/west flash work as a normal
  # user.
  services.udev.packages = [ pkgs.librealsense pkgs.nrf-udev ];

  # GompeiVision builds inside its own Dockerfile.X86/ARM images (it needs
  # allwpilib C++ and openpnp-capture, neither of which is in nixpkgs).
  # Rootless, so using it never needs the root-equivalent `docker` group;
  # setSocketVariable points DOCKER_HOST at the per-user daemon.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
}
