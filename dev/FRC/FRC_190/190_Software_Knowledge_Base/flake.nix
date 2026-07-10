{
  description = "FRC 190 Software Knowledge Base Development Flake";

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

      shellBanner = import ../../../lib/shell-banner.nix;
    in
    {
      devShells = forEachSystem ({ pkgs, ... }: rec {
        # Environment for the 190 Software Knowledge Base docs site
        knowledge-base = pkgs.mkShell {
          name = "190-software-knowledge-base-env";

          packages = [
            pkgs.nodejs_22
          ];

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the 190 Software Knowledge Base Dev Environment";
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
            center "npm run start"
            center "npm run build"
            center "npm run test"
            echo "$BAR"
          '';
        };
        default = knowledge-base;
      });
    };
}
