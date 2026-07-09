{ config, pkgs, lib, inputs, ... }:

{
  programs.direnv = lib.mkDefault {
    enable = true;
    nix-direnv.enable = true;
  };

  # NOTE: allowUnfree is set when pkgs is constructed in flake.nix, not here -
  # setting nixpkgs.config/overlays as a module option is deprecated once
  # home-manager.useGlobalPkgs is enabled.

  home.stateVersion = lib.mkDefault "26.05";

  # NOTE: not wrapped in mkDefault - this is a list, so hosts can add to it
  # with their own `home.packages = with pkgs; [ ... ];`, which concatenates
  # rather than conflicts.
  home.packages = with pkgs; [
    brave

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

  # NOTE: assigned per-key rather than as a blob - home-manager provides its
  # own baseline home.sessionVariables definition, and a blob assignment
  # loses to it wholesale. See the equivalent note in common/configuration.nix.
  home.sessionVariables.SAL_USE_VCLPLUGIN = lib.mkDefault "kf5";

  gtk = lib.mkDefault {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  qt = lib.mkDefault {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  programs.vscode = lib.mkDefault {
    enable = true;
    profiles.default = {
      extensions = [
        pkgs.vscode-extensions.mkhl.direnv
      ];
      userSettings = {
        "window.autoDetectColorScheme" = true;
        "workbench.preferredDarkColorTheme" = "Dark Modern";
        "workbench.preferredLightColorTheme" = "Default Light Modern";
      };
    };
    profiles.frc = {
      extensions = [
        inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.vscode-wpilib
        pkgs.vscode-extensions.mkhl.direnv
      ];
      userSettings = {
        "window.autoDetectColorScheme" = true;
        "workbench.preferredDarkColorTheme" = "Dark Modern";
        "workbench.preferredLightColorTheme" = "Default Light Modern";
        "direnv.restart.automatic" = true;
      };
    };
  };

  xdg.desktopEntries.code-frc = lib.mkDefault {
    name = "VS Code (FRC)";
    genericName = "Text Editor";
    exec = "env WAYLAND_DISPLAY= code --class=code-frc --profile frc -n";
    icon = "/home/elliotscher/.local/share/icons/wpilib-icon.svg";
    comment = "VS Code with FRC WPILib tools and extensions";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" ];
    settings = {
      StartupWMClass = "code-frc";
    };
  };

  # ---------------------------
  # GNOME Settings
  # ---------------------------
  dconf.enable = lib.mkDefault true;
  # NOTE: mkDefault is applied per dconf path (not to the whole dconf.settings
  # blob) - a blob assignment risks being excluded wholesale if anything else
  # ever defines dconf.settings. See the equivalent note further up for
  # environment.shellAliases.
  dconf.settings = {
    "org/gnome/shell" = lib.mkDefault {
      enabled-extensions = [
        "dash-to-dock@micxgx.gmail.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "gsconnect@andyholmes.github.io"
      ];

      disable-user-extensions = false;

      favorite-apps = [
        "brave-browser.desktop"
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
        "org.gnome.Settings.desktop"
        "nixos-manual.desktop"
      ];
    };

    "org/gnome/desktop/interface" = lib.mkDefault {
      color-scheme = "prefer-dark";

      enable-hot-corners = true;

      clock-show-weekday = true;
      clock-show-date = true;
      clock-show-seconds = false;

      show-battery-percentage = true;

      cursor-theme = "Adwaita";
      cursor-size = 24;

      gtk-theme = "Adwaita-dark";
      icon-theme = "Adwaita";
    };

    "org/gnome/desktop/background" = lib.mkDefault {
      picture-uri =
        "file:///home/elliotscher/Pictures/Backgrounds/farewelltolorien.jpg";

      picture-uri-dark =
        "file:///home/elliotscher/Pictures/Backgrounds/lothlorien3.jpg";

      picture-options = "zoom";
    };

    "org/gnome/desktop/screensaver" = lib.mkDefault {
      picture-uri =
        "file:///home/elliotscher/Pictures/Backgrounds/theonering.webp";

      picture-options = "zoom";

      primary-color = "#3465a4";
      secondary-color = "#000000";

      lock-enabled = true;
      lock-delay = lib.hm.gvariant.mkUint32 0;
    };

    "org/gnome/desktop/session" = lib.mkDefault {
      idle-delay = lib.hm.gvariant.mkUint32 300;
    };

    "org/gnome/settings-daemon/plugins/power" = lib.mkDefault {
      sleep-inactive-ac-type = "suspend";
      sleep-inactive-ac-timeout = 3600;

      sleep-inactive-battery-type = "suspend";
      sleep-inactive-battery-timeout = 1800;
    };

    "org/gnome/nautilus/preferences" = lib.mkDefault {
      default-folder-viewer = "icon-view";
      show-hidden-files = true;
      show-delete-permanently = true;
      recursive-search = "always";
    };

    "org/gnome/nautilus/icon-view" = lib.mkDefault {
      default-zoom-level = "standard";
    };

    "org/gnome/desktop/wm/preferences" = lib.mkDefault {
      button-layout = "appmenu:minimize,maximize,close";
      focus-mode = "click";
      num-workspaces = 4;
    };

    "org/gnome/desktop/peripherals/keyboard" = lib.mkDefault {
      repeat = true;
      delay = lib.hm.gvariant.mkUint32 250;
      repeat-interval = lib.hm.gvariant.mkUint32 30;
    };

    "org/gnome/desktop/peripherals/touchpad" = lib.mkDefault {
      tap-to-click = true;
      natural-scroll = true;
      two-finger-scrolling-enabled = true;
      click-method = "fingers";
    };

    "org/gnome/shell/extensions/dash-to-dock" = lib.mkDefault {
      dock-fixed = false;
      autohide = true;
      intellihide = true;
      extend-height = false;

      dock-position = "BOTTOM";

      transparency-mode = "FIXED";
      background-opacity = 0.8;

      dash-max-icon-size = 48;

      show-trash = false;
      show-mounts = false;

      multi-monitor = false;
      click-action = "minimize";
    };
  };

  programs.git = lib.mkDefault {
    enable = true;
    settings = {
      user = {
        name = "ElliotScher";
        email = "ecscher84@gmail.com";
      };
      safe.directory = "/home/elliotscher/Documents/Development/NixHub";
      init.defaultBranch = "main";
      credential = {
        helper = "!gh auth git-credential";
      };
    };
  };

  xdg.desktopEntries.zotero = lib.mkDefault {
    name = "Zotero";
    exec = "zotero -url %U";
    icon = "zotero";
    comment = "Collect, organize, cite, and share your research sources";
    categories = [ "Office" "Database" ];
    mimeType = [ "x-scheme-handler/zotero" "text/plain" ];
    settings = {
      StartupWMClass = "Zotero";
    };
  };

  home.activation.makeVscodeSettingsWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L "$HOME/.config/Code/User/settings.json" ]; then
      target=$(readlink "$HOME/.config/Code/User/settings.json")
      rm "$HOME/.config/Code/User/settings.json"
      cp "$target" "$HOME/.config/Code/User/settings.json"
      chmod u+w "$HOME/.config/Code/User/settings.json"
    fi

    if [ -L "$HOME/.config/Code/User/profiles/frc/settings.json" ]; then
      target=$(readlink "$HOME/.config/Code/User/profiles/frc/settings.json")
      rm "$HOME/.config/Code/User/profiles/frc/settings.json"
      cp "$target" "$HOME/.config/Code/User/profiles/frc/settings.json"
      chmod u+w "$HOME/.config/Code/User/profiles/frc/settings.json"
    fi
  '';

}
