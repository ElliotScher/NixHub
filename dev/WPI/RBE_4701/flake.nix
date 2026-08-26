{
  description = "RBE 4701 Development Flake";

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
        # Environment for the RBE 4701 project
        rbe-4701 = pkgs.mkShell {
          name = "rbe-4701";

          packages = [
            pkgs.python3
            pkgs.uv
          ];

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the RBE 4701 Development Environment";
              subtitle = "Using base Python and uv.";
            }}
            echo ""

            # 1. Automatically create/sync the virtual environment using uv
            if [ ! -d ".venv" ]; then
              center "Creating virtual environment and syncing dependencies..."
              uv venv
              VIRTUAL_ENV=.venv uv sync
            elif [ "uv.lock" -nt ".venv" ]; then
              center "uv.lock updated. Syncing dependencies..."
              VIRTUAL_ENV=.venv uv sync
              touch .venv
            else
              center "Dependencies are up-to-date."
            fi

            # 2. Automatically activate the virtual environment
            source .venv/bin/activate

            echo ""
            center "You can run your project using:"
            center "python <your_script>.py"
            echo "$BAR"
          '';
        };
        default = rbe-4701;
      });
    };
}
