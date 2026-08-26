{ config, pkgs, lib, inputs, ... }:

{
  # ---------------------------
  # Nix settings
  # ---------------------------
  nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = lib.mkDefault true;

  # Trust elliotscher (and root) to supply extra-substituters /
  # extra-trusted-public-keys via a flake's `nixConfig` (e.g. project flakes
  # pulling from ros.cachix.org) without an interactive per-shell prompt, and
  # without Nix silently ignoring the setting because the invoking user is
  # untrusted.
  #
  # mkForce, not mkDefault: upstream's own nix.nix module sets this list via
  # a plain (priority-100) assignment, which already beats mkDefault
  # (priority 1000) outright - a plain assignment here would only get merged
  # in via list concatenation, not reliably override it.
  nix.settings.trusted-users = lib.mkForce [ "root" "elliotscher" ];

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
  boot.loader.grub.theme = lib.mkDefault (pkgs.callPackage ./grub-theme-mr-robot.nix { });
  boot.loader.grub.gfxmodeEfi = lib.mkDefault "1920x1080";
  boot.loader.grub.gfxmodeBios = lib.mkDefault "1920x1080";
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

  # GNOME Shell can silently reset org/gnome/shell/enabled-extensions back to
  # empty on its own (observed after a shell version upgrade triggered its
  # "welcome" flow), clobbering whatever home-manager's dconf activation had
  # written. A locked system dconf database always wins over the user db, so
  # this makes the setting stick no matter what GNOME (or the Extensions app)
  # later writes. Keep this list in sync with the
  # dconf.settings."org/gnome/shell".enabled-extensions list in
  # ../users/elliotscher/home.nix.
  programs.dconf.profiles.user.databases = lib.mkDefault [
    {
      settings."org/gnome/shell".enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "gsconnect@andyholmes.github.io"
        "live-lockscreen@nick-redwill"
      ];
      locks = [ "/org/gnome/shell/enabled-extensions" ];
    }
  ];

  # gnomeExtensions.live-lock-screen renders video through the GStreamer
  # element gtk4paintablesink, which lives in gst-plugins-rs - a package
  # GNOME Shell's own build doesn't bundle (it only wraps itself with
  # gst-plugins-base/good). PAM sources /etc/set-environment into every
  # session on NixOS, including GDM's, so exposing the plugin path here makes
  # it visible system-wide; gnome-shell's wrapper then prefixes its own
  # GST_PLUGIN_SYSTEM_PATH_1_0 onto whatever's already in the environment, so
  # both plugin sets end up on the combined search path.
  environment.variables.GST_PLUGIN_SYSTEM_PATH_1_0 =
    lib.mkDefault "${pkgs.gst_all_1.gst-plugins-rs}/lib/gstreamer-1.0";

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

    # gnomeExtensions.live-lock-screen spawns a helper process ("gjs -m
    # .../external/run.js") to actually decode and render the video - a
    # separate process from GNOME Shell itself, found by searching $PATH for
    # a plain "gjs", which NixOS doesn't provide by default. That bare gjs
    # also has no way to find GTK4's or GStreamer's typelibs, or GStreamer's
    # plugins, since those are normally baked into an app's wrapper at build
    # time. Build that wrapper ourselves the same way nixpkgs would for any
    # other GTK4 app - listing the needed libraries as buildInputs lets their
    # setup hooks populate GI_TYPELIB_PATH/GST_PLUGIN_SYSTEM_PATH_1_0, which
    # gets captured into the wrapper - and put the result on $PATH as the
    # only "gjs" available.
    (symlinkJoin {
      name = "gjs-with-gtk4-gst";
      paths = [ gjs ];
      buildInputs = [
        makeWrapper
        gobject-introspection
        gtk4
      ] ++ (with gst_all_1; [
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly
        gst-libav
        gst-plugins-rs
      ]);
      postBuild = ''
        wrapProgram $out/bin/gjs \
          --set GI_TYPELIB_PATH "$GI_TYPELIB_PATH" \
          --set GST_PLUGIN_SYSTEM_PATH_1_0 "$GST_PLUGIN_SYSTEM_PATH_1_0"
      '';
    })
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
