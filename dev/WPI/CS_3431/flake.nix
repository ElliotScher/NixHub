{
  description = "CS 3431 Development Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Supported systems for development
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # Helper function to generate attributes for each system
      forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f rec {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true; # Allow unfree packages if needed
        };
      });

      shellBanner = import ../../lib/shell-banner.nix;

      # Oracle SQL Developer, for connecting to the WPI Oracle server.
      # nixpkgs dropped its sqldeveloper package, so it's built here from
      # Oracle's platform-independent "no-jre" zip (downloadable without an
      # Oracle account login) plus a Nix JDK. Bump `version` + `hash` from
      # https://www.oracle.com/database/sqldeveloper/technologies/download/
      mkSqlDeveloper = pkgs:
        let
          # SQL Developer 24.3+ supports JDK 17 and 21.
          jdk = pkgs.jdk21;
        in
        pkgs.stdenvNoCC.mkDerivation rec {
          pname = "sqldeveloper";
          version = "26.2.0.186.2220";

          src = pkgs.fetchurl {
            url = "https://download.oracle.com/otn_software/java/sqldeveloper/sqldeveloper-${version}-no-jre.zip";
            hash = "sha256-aULAc7C23wmnFQPf11TGx9p9Wt3DCl6JvO5nTzH8230=";
          };

          nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];

          unpackPhase = ''
            unzip -q $src
          '';

          # The launcher resolves every conf/jar path relative to
          # sqldeveloper/bin, hence --chdir. OIDE_JAVA_HOME is the launcher's
          # global JDK override: without it, the first run interactively
          # asks for a JDK path and saves it to
          # ~/.sqldeveloper/<version>/product.conf, which would then go
          # stale whenever the JDK's store path changes. All user state
          # (connections, preferences) lives in ~/.sqldeveloper, so the
          # read-only store install is fine.
          #
          # The launcher runs `file` on the java binary to decide 32 vs
          # 64-bit; if `file` is missing it silently assumes 32-bit and caps
          # the heap at 800M instead of 2G.
          #
          # The bundled JavaFX natives (welcome page, instance viewer)
          # dlopen GTK & co., which aren't on NixOS's default library path.
          installPhase = ''
            mkdir -p $out/libexec $out/bin $out/share/pixmaps
            cp -r sqldeveloper $out/libexec/
            cp sqldeveloper/icon.png $out/share/pixmaps/sqldeveloper.png

            makeWrapper ${pkgs.bash}/bin/bash $out/bin/sqldeveloper \
              --chdir $out/libexec/sqldeveloper/sqldeveloper/bin \
              --add-flags $out/libexec/sqldeveloper/sqldeveloper/bin/sqldeveloper \
              --set OIDE_JAVA_HOME ${jdk.home} \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.file ]} \
              ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [
                  pkgs.gtk3
                  pkgs.glib
                  pkgs.pango
                  pkgs.cairo
                  pkgs.gdk-pixbuf
                  pkgs.freetype
                  pkgs.fontconfig
                  pkgs.libGL
                  pkgs.libx11
                  pkgs.libxtst
                  pkgs.libxxf86vm
                ]}
              ''}
          '';

          meta = {
            description = "Oracle SQL Developer";
            homepage = "https://www.oracle.com/database/sqldeveloper/";
            license = pkgs.lib.licenses.unfree;
            sourceProvenance = [ pkgs.lib.sourceTypes.binaryBytecode pkgs.lib.sourceTypes.binaryNativeCode ];
            mainProgram = "sqldeveloper";
          };
        };
    in
    {
      packages = forEachSystem ({ pkgs, ... }: rec {
        sqldeveloper = mkSqlDeveloper pkgs;
        default = sqldeveloper;
      });

      devShells = forEachSystem ({ pkgs, ... }: rec {
        # Environment for the CS 3431 (Database Systems I) coursework
        cs-3431 = pkgs.mkShell {
          name = "cs-3431";

          packages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.sqldeveloper
          ];

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the CS 3431 Development Environment";
              subtitle = "Using Oracle SQL Developer ${self.packages.${pkgs.stdenv.hostPlatform.system}.sqldeveloper.version}.";
            }}
            echo ""
            center "You can launch SQL Developer using:"
            center "sqldeveloper &"
            echo "$BAR"
          '';
        };
        default = cs-3431;
      });
    };
}
