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
        # nixpkgs builds tkinter as a separate composable package rather
        # than baking it into the base python3 derivative (see
        # pkgs/development/python-modules/tkinter) - it's added here via
        # withPackages so `import tkinter` (and matplotlib's TkAgg backend)
        # work out of the box, without depending on any GUI toolkit bindings
        # (PyQt, PyGObject, ...) being pip/uv-installable.
        pythonWithTk = pkgs.python3.withPackages (ps: [ ps.tkinter ]);

        # Environment for the RBE 4701 project
        rbe-4701 = pkgs.mkShell {
          name = "rbe-4701";

          packages = [
            pythonWithTk
            pkgs.uv
            pkgs.stdenv.cc.cc.lib
          ];

          shellHook = ''
            # Prebuilt manylinux wheels (numpy, matplotlib, etc., however
            # they land in .venv - via uv, or plain pip) dynamically link (or
            # dlopen at runtime) a small set of "assumed present" system libs
            # that aren't on NixOS's default library path. Listing the
            # packages under `packages` alone does NOT put them on
            # LD_LIBRARY_PATH for an interactive shell - `mkShell` doesn't
            # wire that up automatically - so it has to be exported here
            # explicitly:
            #   - libstdc++.so.6, libz.so.1: linked directly by numpy's
            #     compiled extensions; missing either fails the import with
            #     "ImportError: lib____.so.___: cannot open shared object file".
            #   - libX11: matplotlib's _c_internal_utils dlopens this at
            #     runtime just to check whether a display is available
            #     (_c_internal_utils.display_is_valid()). Without it, that
            #     check silently returns false (no exception, no warning
            #     pointing at the real cause) and matplotlib's backend
            #     auto-detection concludes "headless", overriding TkAgg back
            #     to plain Agg even with MPLBACKEND=TkAgg set below.
            #   - glib (libglib-2.0, libgthread-2.0): pulled in indirectly
            #     by pygame's bundled extension modules.
            #   - the X11 extension libs (libXext, libXcursor, libXi,
            #     libXrandr, libXfixes, libXrender) and the Wayland/xkb
            #     libs (wayland, libxkbcommon, libdecor): SDL2 (bundled in
            #     pygame) dlopen()s these itself when it initializes its
            #     x11/wayland video driver backend - they never show up as
            #     NEEDED entries in `ldd`, so a missing one doesn't error,
            #     it just makes that whole backend report "not available"
            #     and pygame silently falls back to the headless "dummy"/
            #     "offscreen" driver (no window, no exception).
            export LD_LIBRARY_PATH="${
              pkgs.lib.makeLibraryPath [
                pkgs.stdenv.cc.cc.lib
                pkgs.zlib
                pkgs.libx11
                pkgs.glib
                pkgs.libxext
                pkgs.libxcursor
                pkgs.libxi
                pkgs.libxrandr
                pkgs.libxfixes
                pkgs.libxrender
                pkgs.wayland
                pkgs.libxkbcommon
                pkgs.libdecor
              ]
            }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

            # matplotlib's own backend auto-detection doesn't pick TkAgg
            # here even though it works fine when set explicitly - so pin it
            # rather than relying on auto-detection (default: `agg`, which
            # is headless and silently drops any interactive show()/animation).
            export MPLBACKEND=TkAgg

            ${shellBanner {
              title = "Welcome to the RBE 4701 Development Environment";
              subtitle = "Using base Python and uv.";
            }}
            echo ""

            # 1. Automatically create/sync the virtual environment using uv
            if [ ! -d ".venv" ]; then
              center "Creating virtual environment and syncing dependencies..."
              # --system-site-packages so this project's isolated venv can
              # still see tkinter from pythonWithTk's own site-packages
              # above (uv's venvs are isolated by default, same as stdlib
              # venv - third-party packages like tkinter aren't inherited
              # from the base interpreter without this flag).
              uv venv --system-site-packages --python "${pythonWithTk}/bin/python3"
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
