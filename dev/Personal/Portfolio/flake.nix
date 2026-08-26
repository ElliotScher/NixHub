{
  description = "Personal Portfolio Development Flake";

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
    in
    {
      devShells = forEachSystem ({ pkgs, ... }: rec {
        # Environment for the Portfolio project
        portfolio = pkgs.mkShell {
          name = "portfolio";

          packages = [
            pkgs.nodejs_22
            pkgs.chromium
          ];

          shellHook = ''
            # Point puppeteer (used by scripts/build-resumes.js) at nixpkgs' Chromium
            # instead of letting it download its own (which doesn't work well on NixOS).
            export PUPPETEER_SKIP_DOWNLOAD=true
            export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
            export PUPPETEER_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"

            ${shellBanner {
              title = "Welcome to the Personal Portfolio Dev Environment";
              subtitle = "Using Node.js $(node --version) and npm.";
            }}
            echo ""

            # 1. Automatically install/sync node_modules from package-lock.json
            if [ ! -d "node_modules" ]; then
              center "Installing dependencies..."
              npm install
            elif [ "package-lock.json" -nt "node_modules" ]; then
              center "package-lock.json updated. Reinstalling dependencies..."
              npm install
              touch node_modules
            else
              center "Dependencies are up-to-date."
            fi

            echo ""
            center "You can run your project using:"
            center "npm run dev"
            center "npm run build"
            center "npm run test"
            center "npm run build-resumes"
            echo "$BAR"
          '';
        };
        default = portfolio;
      });
    };
}
