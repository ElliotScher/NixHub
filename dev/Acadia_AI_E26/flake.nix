{
  description = "Acadia AI E26 IQP Group Development Flake";

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
        
        # Library path for PyPI wheels on NixOS (includes X11, GL, DBus, and Qt6 dependencies)
        libPath = pkgs.lib.makeLibraryPath [
          pkgs.stdenv.cc.cc
          pkgs.zlib
          pkgs.zstd
          pkgs.glib
          pkgs.libGL
          pkgs.libx11
          pkgs.libxext
          pkgs.libxrender
          pkgs.libxi
          pkgs.libxcb
          pkgs.libxcb-cursor
          pkgs.libxkbcommon
          pkgs.dbus.lib
          pkgs.fontconfig
          pkgs.freetype
          pkgs.wayland
          pkgs.libxcb-wm
          pkgs.libxcb-image
          pkgs.libxcb-keysyms
          pkgs.libxcb-render-util
        ];
      });

      shellBanner = import ../lib/shell-banner.nix;
    in
    {
      devShells = forEachSystem ({ pkgs, libPath, ... }: rec {
        # Environment for the Acadia AI project
        acadia-ai = pkgs.mkShell {
          name = "acadia-ai-e26-env";

          packages = [
            pkgs.python3
            pkgs.uv
            pkgs.tesseract
          ];

          shellHook = ''
            # Setup LD_LIBRARY_PATH for PyPI wheels inside the shell
            export LD_LIBRARY_PATH="${libPath}:$LD_LIBRARY_PATH"

            ${shellBanner {
              title = "Welcome to the Acadia AI E26 Development Environment";
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

            # 2. Setup stable python wrappers to make PyCharm work without plugins
            center "Creating Python interpreter wrappers for IDE compatibility..."
            rm -f .venv/bin/python .venv/bin/python3 .venv/bin/python-real .venv/bin/python3-real
            ln -sfn ${pkgs.python3}/bin/python3 .venv/bin/python-real
            ln -sfn ${pkgs.python3}/bin/python3 .venv/bin/python3-real

            # Determine python version dynamically (e.g. python3.13)
            PYTHON_VERSION=$(${pkgs.python3}/bin/python3 -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')")

            # Helper function to generate interpreter wrapper scripts
            write_wrapper() {
              local target="$1"
              local real_bin="$2"
              echo "#!/bin/sh" > "$target"
              echo 'export VIRTUAL_ENV="$(cd "$(dirname "$0")/.." && pwd)"' >> "$target"
              echo 'export PYTHONPATH="$VIRTUAL_ENV/lib/'"$PYTHON_VERSION"'/site-packages:$PYTHONPATH"' >> "$target"
              echo 'export LD_LIBRARY_PATH="'"${libPath}"':$LD_LIBRARY_PATH"' >> "$target"
              echo 'exec "$VIRTUAL_ENV/bin/'"$real_bin"'" "$@"' >> "$target"
              chmod +x "$target"
            }

            write_wrapper .venv/bin/python python-real
            write_wrapper .venv/bin/python3 python3-real

            # 3. Automatically activate the virtual environment
            source .venv/bin/activate

            echo ""
            center "You can run your project using:"
            center "python src/detection/yolo.py"
            echo "$BAR"
          '';
        };
        default = acadia-ai;
      });
    };
}
