{ config, pkgs, lib, inputs, ... }:

let
  # The icon ships inside the vscode-wpilib extension's own (versioned)
  # directory, so its path shifts on every frc-nix update - pull it out by
  # name at build time instead of hardcoding a path that'll go stale.
  wpilibIcon = pkgs.runCommand "wpilib-icon.svg" { } ''
    cp "$(find ${inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.vscode-wpilib} -name 'wpilib-icon.svg' | head -n1)" "$out"
  '';

  # The only JDK that's ever a permanent part of this closure - it's
  # referenced directly (not via the flake below) purely to host
  # redhat.java's language server, which needs Java 21+ just to run,
  # independent of whatever JDK the open project actually builds with.
  # Shared by both FRC profiles below.
  frcJdk21 = pkgs.jdk21;

  # JDK 17 (roboRIO) and JDK 25 (SystemCore) are NOT referenced here at all -
  # they exist only as devshells in this flake, so Nix only builds/fetches
  # whichever one a given launcher actually enters, rather than keeping
  # both permanently installed.
  frcRobotCodeFlake = "/home/elliotscher/Documents/NixHub/dev/FRC/FRC_190/Robot_Code";

  # Two separate profiles/launchers (roboRIO vs SystemCore), each wrapping
  # its own fixed devshell, rather than one profile with a runtime
  # switch: VS Code enforces a single running instance *per profile*, so a
  # single shared profile can't have two simultaneously-open windows with
  # different real environments anyway - a second launch would just open a
  # window in the first one's already-running process, silently ignoring
  # whichever JDK the second launch tried to select. Separate profiles give
  # separate single-instance locks, so both can genuinely be open at once,
  # each with only its own JDK (17 or 25) ever reachable - JDK 21 is never
  # part of either devshell, so neither can build using it.
  mkFrcCodeLauncher = devShellAttr: pkgs.writeShellScript "code-frc-${devShellAttr}-launcher" ''
    exec ${pkgs.nix}/bin/nix develop "${frcRobotCodeFlake}#${devShellAttr}" --command code --class=code-frc-${devShellAttr} --profile frc-${devShellAttr} -n
  '';

  defaultVscodeExtensions = [
    pkgs.vscode-extensions.github.vscode-pull-request-github
    pkgs.vscode-extensions.eamodio.gitlens
  ];

  defaultVscodeUserSettings = {
    "window.autoDetectColorScheme" = true;
    "workbench.preferredDarkColorTheme" = "Dark Modern";
    "workbench.preferredLightColorTheme" = "Default Light Modern";
    "editor.hover.enabled" = true;
    "editor.hover.delay" = 500;
  };
in
{
  programs.direnv = lib.mkDefault {
    enable = true;
    nix-direnv.enable = true;
  };

  # NOTE: allowUnfree is set when pkgs is constructed in flake.nix, not here -
  # setting nixpkgs.config/overlays as a module option is deprecated once
  # home-manager.useGlobalPkgs is enabled.

  home.stateVersion = lib.mkDefault "26.05";

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
      extensions = defaultVscodeExtensions;
      # Extensions here are declaratively pinned via nixpkgs and read-only,
      # so VSCode's own update prompts can't be acted on anyway - bump
      # nixpkgs and rebuild to get newer versions instead.
      enableExtensionUpdateCheck = false;
      userSettings = defaultVscodeUserSettings;
    };
    profiles.frc-roborio = {
      extensions = defaultVscodeExtensions ++ [
        inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.vscode-wpilib
        pkgs.vscode-extensions.vscjava.vscode-java-pack
        pkgs.vscode-extensions.redhat.java
      ];
      userSettings = defaultVscodeUserSettings // {
        # redhat.java's language server needs Java 21+ just to run, separate
        # from whatever JDK the open project actually builds with (17 here,
        # provided by this profile's wrapped launcher's real process
        # environment, not by a static setting - so it's never a permanent
        # part of this closure).
        "java.jdt.ls.java.home" = "${frcJdk21.home}";
      };
    };
    profiles.frc-systemcore = {
      extensions = defaultVscodeExtensions ++ [
        inputs.frc-nix.packages.${pkgs.stdenv.hostPlatform.system}.vscode-wpilib
        pkgs.vscode-extensions.vscjava.vscode-java-pack
        pkgs.vscode-extensions.redhat.java
      ];
      userSettings = defaultVscodeUserSettings // {
        # Same rationale as frc-roborio above, just for the SystemCore
        # (JDK 25) devshell instead of roboRIO's (JDK 17).
        "java.jdt.ls.java.home" = "${frcJdk21.home}";
      };
    };
  };

  xdg.desktopEntries.code-frc-roborio = lib.mkDefault {
    name = "VS Code (FRC RoboRIO)";
    genericName = "Text Editor";
    exec = "${mkFrcCodeLauncher "roborio"}";
    icon = "${wpilibIcon}";
    comment = "VS Code with FRC WPILib tools and extensions, for roboRIO (JDK 17) robot code";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" ];
    settings = {
      StartupWMClass = "code-frc-roborio";
    };
  };

  xdg.desktopEntries.code-frc-systemcore = lib.mkDefault {
    name = "VS Code (FRC SystemCore)";
    genericName = "Text Editor";
    exec = "${mkFrcCodeLauncher "systemcore"}";
    icon = "${wpilibIcon}";
    comment = "VS Code with FRC WPILib tools and extensions, for SystemCore (JDK 25) robot code";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" ];
    settings = {
      StartupWMClass = "code-frc-systemcore";
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
      # enabled-extensions is deliberately not set here - it's locked via
      # programs.dconf.profiles.user in common/configuration.nix instead, and
      # home-manager's own dconf activation would fail outright ("attempted
      # to modify one or more non-writable keys") if it tried to write a
      # locked key too.

      disable-user-extensions = false;

      favorite-apps = [
        "brave-browser.desktop"
        "google-chrome.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
        "slack.desktop"
        "discord.desktop"
        "spotify.desktop"
        "code.desktop"
        "code-frc-roborio.desktop"
        "code-frc-systemcore.desktop"
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
      safe.directory = "/home/elliotscher/Documents/NixHub";
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

  home.activation.extractBackgrounds = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/Pictures/Backgrounds" ]; then
      mkdir -p "$HOME/Pictures"
      ${pkgs.unzip}/bin/unzip -q ${../common/Backgrounds.zip} -d "$HOME/Pictures"
    fi
  '';

  # makeVscodeSettingsWritable (below) intentionally turns the settings.json
  # symlink back into a writable regular file after every activation. That
  # means the *next* activation's checkLinkTargets step always finds a real
  # file in the way and tries to move it to a `.backup` sibling - which fails
  # if a `.backup` from the previous run is still there (checkLinkTargets
  # runs before writeBoundary, so makeVscodeSettingsWritable never gets a
  # chance to clean it up first). Clear those backups pre-emptively so
  # activation never gets stuck failing on itself.
  home.activation.removeStaleVscodeSettingsBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f \
      "$HOME/.config/Code/User/settings.json.backup" \
      "$HOME/.config/Code/User/profiles/frc-roborio/settings.json.backup" \
      "$HOME/.config/Code/User/profiles/frc-systemcore/settings.json.backup"
  '';

  home.activation.makeVscodeSettingsWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for settings in \
      "$HOME/.config/Code/User/settings.json" \
      "$HOME/.config/Code/User/profiles/frc-roborio/settings.json" \
      "$HOME/.config/Code/User/profiles/frc-systemcore/settings.json"
    do
      if [ -L "$settings" ]; then
        target=$(readlink "$settings")
        rm "$settings"
        cp "$target" "$settings"
        chmod u+w "$settings"
      fi
    done
  '';

}
