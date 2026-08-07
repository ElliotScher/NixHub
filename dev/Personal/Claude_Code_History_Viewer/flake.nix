{
  description = "Claude Code History Viewer Development Flake";

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

        # Native libraries required by Tauri's WebKitGTK webview on Linux
        # (see LINUX_BUILD.md in the project for the apt-package equivalents)
        tauriLibs = with pkgs; [
          glib
          gtk3
          cairo
          pango
          gdk-pixbuf
          at-spi2-atk
          harfbuzz
          librsvg
          libsoup_3
          webkitgtk_4_1
          libayatana-appindicator
          openssl
          dbus
        ];
      });

      shellBanner = import ../lib/shell-banner.nix;
    in
    {
      devShells = forEachSystem ({ pkgs, tauriLibs, ... }: rec {
        # Environment for the Claude Code History Viewer project (Tauri + React)
        claude-code-history-viewer = pkgs.mkShell {
          name = "claude-code-history-viewer-env";

          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.wrapGAppsHook3
          ];

          packages = [
            pkgs.nodejs_22
            pkgs.pnpm
            pkgs.just
            pkgs.rustc
            pkgs.cargo
            pkgs.rustfmt
            pkgs.clippy
          ] ++ tauriLibs;

          shellHook = ''
            # Tauri's Rust side needs these WebKitGTK/GTK libs discoverable at
            # both compile time (pkg-config) and runtime (LD_LIBRARY_PATH),
            # since NixOS doesn't keep shared libs in the standard system paths.
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath tauriLibs}:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPath "lib/pkgconfig" tauriLibs}:$PKG_CONFIG_PATH"

            ${shellBanner {
              title = "Welcome to the Claude Code History Viewer Dev Environment";
              subtitle = "Using Node.js $(node --version), pnpm, and $(rustc --version).";
            }}
            echo ""

            if [ -f "package.json" ]; then
              # 1. Automatically install/sync node_modules from pnpm-lock.yaml
              if [ ! -d "node_modules" ]; then
                center "Installing dependencies..."
                pnpm install
              elif [ "pnpm-lock.yaml" -nt "node_modules" ]; then
                center "pnpm-lock.yaml updated. Reinstalling dependencies..."
                pnpm install
                touch node_modules
              else
                center "Dependencies are up-to-date."
              fi

              echo ""
              center "You can run your project using:"
              center "just dev"
              center "just tauri-build"
              center "pnpm test"
            else
              center "No project checked out here yet. Clone it first:"
              center "git clone https://github.com/jhlee0409/claude-code-history-viewer.git ."
            fi
            echo "$BAR"
          '';
        };
        default = claude-code-history-viewer;
      });
    };
}
