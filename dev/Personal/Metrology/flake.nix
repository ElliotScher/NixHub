{
  description = "Metrology Development Flake";

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
        # Environment for the Metrology project
        metrology = pkgs.mkShell {
          name = "metrology";

          packages = [
            pkgs.python3
            pkgs.uv
            pkgs.graphviz # provides the `dot` CLI used by scripts/build_graph.py
          ];

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the Metrology Dev Environment";
              subtitle = "Using Python $(python3 --version) and uv.";
            }}
            echo ""

            if [ -f "pyproject.toml" ]; then
              # 1. Automatically create/sync the virtual environment using uv
              if [ ! -d ".venv" ]; then
                center "Creating virtual environment and syncing dependencies..."
                uv venv --python "${pkgs.python3}/bin/python3"
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
              center "python scripts/validate.py"
              center "python scripts/build_graph.py"
            else
              center "No project checked out here yet. cd into:"
              center "~/Documents/Development/Personal/Metrology"
            fi
            echo "$BAR"
          '';
        };
        default = metrology;
      });
    };
}
