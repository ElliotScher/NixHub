{ config, pkgs, lib, inputs, ... }:

{
  # ---------------------------
  # Nix settings
  # ---------------------------
  nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = lib.mkDefault true;

  # NOTE: allowUnfree is set when pkgs is constructed in flake.nix, not here -
  # setting nixpkgs.config/overlays as a module option is deprecated once
  # home-manager.useGlobalPkgs is enabled.

  # Enable nix-ld to run pre-compiled Gradle/wpilib binaries dynamically
  programs.nix-ld.enable = lib.mkDefault true;

  nix.gc = lib.mkDefault {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # ---------------------------
  # Bootloader
  # ---------------------------
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.efiSupport = lib.mkDefault true;
  boot.loader.grub.device = lib.mkDefault "nodev";
  boot.loader.grub.useOSProber = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # ---------------------------
  # Networking
  # ---------------------------
  networking.networkmanager.enable = lib.mkDefault true;

  # ---------------------------
  # Time / Locale
  # ---------------------------
  time.timeZone = lib.mkDefault "America/New_York";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # ---------------------------
  # GNOME Desktop
  # ---------------------------
  services.xserver.enable = lib.mkDefault true;

  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;
  services.gnome.core-apps.enable = lib.mkDefault true;

  programs.dconf.enable = lib.mkDefault true;

  # ---------------------------
  # Keyboard layout
  # ---------------------------
  services.xserver.xkb = lib.mkDefault {
    layout = "us";
    variant = "";
  };

  # ---------------------------
  # Audio (PipeWire)
  # ---------------------------
  security.rtkit.enable = lib.mkDefault true;

  services.pipewire = lib.mkDefault {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ---------------------------
  # Printing
  # ---------------------------
  services.printing.enable = lib.mkDefault true;

  # ---------------------------
  # Firmware updates
  # ---------------------------
  services.fwupd.enable = lib.mkDefault true;

  # ---------------------------
  # Fingerprint Sensor
  # ---------------------------
  services.fprintd.enable = lib.mkDefault true;

  # ---------------------------
  # System packages
  # ---------------------------
  # NOTE: not wrapped in mkDefault - this is a list, so hosts can add to it
  # with a plain `environment.systemPackages = with pkgs; [ ... ];` of their
  # own, which concatenates rather than conflicts.
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    fprintd
  ];

  # ---------------------------
  # Shell Aliases (System-wide)
  # ---------------------------
  # NOTE: assigned per-key rather than as one mkDefault-wrapped blob - NixOS
  # provides its own baseline environment.shellAliases definition, and a
  # blob assignment loses to it wholesale (dropping every key, not just
  # overlapping ones). Per-key assignment only competes on the exact same
  # key, so it doesn't get excluded like that.
  environment.shellAliases.grep = lib.mkDefault "grep --color=auto";
  environment.shellAliases.fgrep = lib.mkDefault "fgrep --color=auto";
  environment.shellAliases.egrep = lib.mkDefault "egrep --color=auto";
  environment.shellAliases.gs = lib.mkDefault "git status";
  environment.shellAliases.gp = lib.mkDefault "git pull";
  environment.shellAliases.gco = lib.mkDefault "git checkout";
  environment.shellAliases.gb = lib.mkDefault "git branch";
  environment.shellAliases.fuck = lib.mkDefault "echo \"Fuck This Shit, Rebooting\" && sudo reboot now";
  environment.shellAliases.fuckoff = lib.mkDefault "echo \"Fuck This Shit, I'm Out\" && sudo shutdown now";

  # ---------------------------
  # System version
  # ---------------------------
  system.stateVersion = lib.mkDefault "26.05";
}
