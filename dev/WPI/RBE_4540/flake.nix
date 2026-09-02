{
  description = "RBE 4540 ROS 2 (Jazzy) Development Flake";

  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
  };
  outputs = { self, nix-ros-overlay, nixpkgs }:
    nix-ros-overlay.inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix-ros-overlay.overlays.default ];
        };

        # `pkgs.colcon` (ROS-overlaid) already bundles colcon-ros, -cmake,
        # -mixin and -argcomplete, so it alone is enough to discover and
        # build ament packages. `colcon-cd` is the one extension that can't
        # be added to it: in nix-ros-overlay's package set, colcon-cd pulls
        # in colcon-package-information, which resolves to a *different*
        # `colcon-core` build (pinned to an older `empy` for ROS ament
        # compatibility) than the one colcon-cd depends on directly -
        # nixpkgs then refuses to build it as a duplicate-package conflict.
        # A plain (non-ROS-overlaid) nixpkgs has no such pin, so colcon-cd
        # is pulled from there instead, as its own self-contained package -
        # it doesn't need to share a closure with `pkgs.colcon` to work.
        pkgsPlain = import nixpkgs { inherit system; };

        # The upstream colcon mixins (release, debug, ccache, lld, ...),
        # pinned instead of fetched imperatively via `colcon mixin add` +
        # `update` (which write network-fetched state into ~/.colcon).
        # colcon-mixin reads any directory on COLCON_MIXIN_PATH directly, so
        # pointing it at this store path is enough - no repository
        # registration step needed.
        colconMixinRepo = pkgsPlain.fetchFromGitHub {
          owner = "colcon";
          repo = "colcon-mixin-repository";
          rev = "7558e35befbff0d88d9b8f701b3ab1b073cbcaba"; # default branch HEAD, 2025-11-07
          hash = "sha256-VWLI/FtHROcndI0D6kiQ7PupKsOvAcUXB6G6nqcMjx0=";
        };

        shellBanner = import ../../lib/shell-banner.nix;

        # Qt5 plugin search path (platforms/xcb, wayland, svg icons, ...)
        # for any Qt5 GUI node built locally in a workspace (e.g. a
        # colcon-rebuilt turtlesim_node, following the "modifying
        # turtlesim" tutorial). A prebuilt Nix package like
        # rosPackages.jazzy.turtlesim gets this baked into its own
        # `makeCWrapper`-generated executable at build time via
        # `wrapQtAppsHook`, but a plain colcon/cmake build has no such
        # wrapping - without QT_PLUGIN_PATH set in the environment it runs
        # in, Qt can't find the "xcb" platform plugin and aborts on
        # startup. Same qt5 packages and relative plugin prefix
        # (`qtPluginPrefix`) that wrapQtAppsHook itself would use.
        qt5PluginPath = pkgs.lib.concatMapStringsSep ":"
          (pkg: "${pkg}/${pkgs.qt5.qtbase.qtPluginPrefix}") [
            pkgs.qt5.qtbase
            pkgs.qt5.qtsvg.bin
            pkgs.qt5.qtdeclarative.bin
            pkgs.qt5.qtwayland.bin
          ];
      in {
        devShells = rec {
          rbe-4540-ros2 = pkgs.mkShell {
            name = "rbe-4540-ros2";
            packages = [
              pkgs.neovim
              pkgs.colcon
              pkgsPlain.python3Packages.colcon-cd
              pkgs.eigen # the actual Eigen3 headers - a plain nixpkgs
                # library, not a ROS package, so it isn't in rosPackages.jazzy
                # at all. Needed by any node that does `#include <Eigen/...>`
                # (e.g. custom_cpp_srvcli's grasp-matrix server).
              (with pkgs.rosPackages.jazzy; buildEnv {
                paths = [
                  desktop # ros-base + rviz2 + rqt + demos/tutorials
                  rviz2
                  rqt
                  demo-nodes-cpp
                  ament-cmake-core.out # workaround: nix-ros-overlay only
                    # propagates the `dev` output (a no-op marker) of this
                    # package, not `out` (which holds the actual
                    # ament_cmake_coreConfig.cmake), so find_package() fails
                    # without it explicitly listed here.
                  python-cmake-module # needed at CMake configure time by
                    # rosidl_generate_interfaces (e.g. turtlesim's own .msg/
                    # .srv), but not pulled in transitively by `desktop`.
                  eigen3-cmake-module # ament/CMake glue package (rosdep key
                    # `eigen3_cmake_module`) that provides an
                    # ament_cmake-compatible Eigen3Config.cmake wrapping the
                    # plain `pkgs.eigen` above - required by any package
                    # whose CMakeLists.txt does
                    # `find_package(eigen3_cmake_module REQUIRED)` +
                    # `find_package(Eigen3 REQUIRED)`.
                 turtlesim
                ];
              })
            ];

            shellHook = ''
              # `ls -l` of any connected serial/USB robot hardware, and their
              # perms - handy since NixOS grants /dev/ttyUSB*, /dev/ttyACM*
              # access via a system-level group (see below), not a package.
              alias lsdev="ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null"

              # Snapshot of the env vars a workspace overlay touches, taken
              # before any workspace is sourced - so switching between
              # workspaces later can restore this baseline first instead of
              # stacking one workspace's overlay on top of another's.
              for _v in AMENT_PREFIX_PATH CMAKE_PREFIX_PATH PATH PYTHONPATH LD_LIBRARY_PATH PKG_CONFIG_PATH; do
                export "_ros_pristine_$_v=''${!_v}"
              done
              unset _v

              # colcon_cd: the shell function itself, plus its bash tab
              # completion, and colcon's own bash tab completion
              # (register-python-argcomplete). Unlike Ubuntu's
              # `/usr/share/...` paths, these come from the colcon-cd and
              # colcon-argcomplete packages' own store outputs. argcomplete
              # is read from the ROS-overlaid pkgs since that's the build
              # already embedded in pkgs.colcon's closure above.
              source ${pkgsPlain.python3Packages.colcon-cd}/share/colcon_cd/function/colcon_cd.sh
              source ${pkgsPlain.python3Packages.colcon-cd}/share/colcon_cd/function/colcon_cd-argcomplete.bash
              source ${pkgs.python3Packages.colcon-argcomplete}/share/colcon_argcomplete/hook/colcon-argcomplete.bash

              # colcon mixins (e.g. `colcon build --mixin release`), pinned
              # via colconMixinRepo above instead of `colcon mixin add` +
              # `update` writing state into ~/.colcon.
              export COLCON_MIXIN_PATH="${colconMixinRepo}"

              # See qt5PluginPath above - lets a locally-built Qt5 GUI node
              # (turtlesim_node and friends) find its platform/svg/wayland
              # plugins at runtime, same as a Nix-packaged one already can.
              export QT_PLUGIN_PATH="${qt5PluginPath}"

              # Prompt for the domain ID each time, defaulting to 42 on a
              # bare Enter - or falling back silently when stdin isn't a
              # terminal (e.g. `nix develop -c <cmd>`), since read has
              # nothing to prompt against there.
              if [ -t 0 ]; then
                read -rp "ROS_DOMAIN_ID [42]: " _ros_domain_id
                export ROS_DOMAIN_ID="''${_ros_domain_id:-42}"
                unset _ros_domain_id
              else
                export ROS_DOMAIN_ID=42
              fi

              ${shellBanner {
                title = "Welcome to the RBE 4540 ROS 2 (Jazzy) Development Environment";
                subtitle = "desktop + rviz2 + rqt + colcon";
              }}
              export -f center # so it's still usable from _ros_ws_autosource
                # below when that runs in a child shell (e.g. `nix develop -c
                # bash -c '...'`), not just this same interactive process.
              center "ROS_DOMAIN_ID: $ROS_DOMAIN_ID"
              echo ""

              # Unlike Ubuntu (`sudo usermod -aG dialout $USER`), serial/USB
              # device access on NixOS is granted via extraGroups in the host's
              # system config, so it can't be fixed from inside this project
              # flake - just flag it if it's missing.
              if id -nG "$USER" | grep -qw dialout; then
                center "Serial/USB device access (dialout group): OK"
              else
                center "WARNING: not in the 'dialout' group - can't access"
                center "/dev/ttyUSB*, /dev/ttyACM* (robot hardware) yet."
                center "Add it via users.users.<you>.extraGroups in your"
                center "host's NixOS configuration.nix, then rebuild+switch."
              fi

              # `ros2` is a Nix-generated wrapper that unconditionally
              # re-prepends this environment's AMENT_PREFIX_PATH (and
              # PYTHONPATH/PATH/CMAKE_PREFIX_PATH/...) ahead of whatever a
              # sourced workspace overlay already exported, on every
              # invocation. So `ros2 run`/`ros2 pkg` can never see a
              # locally-rebuilt package that shares a name with one already
              # in this shell (e.g. rebuilding turtlesim in a *_ws to
              # follow the "modifying turtlesim" tutorial) - the
              # Nix-provided one always wins, silently.
              #
              # The wrapper's real Python entry point underneath - the file
              # nixpkgs' `makeWrapper` conventionally names
              # `.<executable-name>-wrapped`, sitting next to the wrapper
              # script in the same output - does no such re-prepending
              # itself; it only extends sys.path for its own dependencies.
              # Calling that directly skips just the offending step and
              # nothing else (ROS_DOMAIN_ID, RMW config, etc. are
              # untouched), so a local overlay's package correctly takes
              # priority.
              #
              # CAVEAT: `.<name>-wrapped` is a private nixpkgs
              # implementation convention, not a public API - it has been
              # stable for years, but a future nix-ros-overlay/nixpkgs
              # update could change it. The check below verifies the file
              # exists before relying on it, and falls back to the normal
              # (shadowing-prone) `ros2` with an explicit warning instead
              # of failing silently if that ever happens.
              _ros2cli_inner="${pkgs.rosPackages.jazzy.ros2cli}/bin/.ros2-wrapped"
              if [ -x "$_ros2cli_inner" ]; then
                ros2() { "${pkgs.rosPackages.jazzy.ros2cli}/bin/.ros2-wrapped" "$@"; }
                export -f ros2
              else
                center "WARNING: ros2's unwrapped entry point was not"
                center "found at the expected path - nixpkgs' internal"
                center "wrapper naming convention likely changed."
                center "'ros2 run'/'ros2 pkg' will now NOT see"
                center "locally-rebuilt packages that share a name with"
                center "one already in this shell (e.g. an overlaid"
                center "turtlesim) - the Nix-provided one will silently"
                center "win instead."
                center "Workaround: run the built executable directly,"
                center "e.g. ./install/<pkg>/lib/<pkg>/<node>, after"
                center "sourcing install/setup.bash."
                center "To fix: find the new unwrapped entry point (check"
                center "\$(dirname \$(readlink -f \$(command -v ros2)))"
                center "for a hidden file next to ros2) and update"
                center "_ros2cli_inner in this flake's shellHook."
              fi
              unset _ros2cli_inner
              echo ""

              # Auto-source a workspace overlay (install/setup.bash, falling
              # back to install/local_setup.bash) whenever $PWD is a
              # directory ending in `_ws` - not just at shell entry, but on
              # every `cd`, via PROMPT_COMMAND, so hopping between different
              # assignments' workspaces in one shell just works. Each switch
              # restores the pristine snapshot from above first, so unrelated
              # workspaces' overlays don't stack on top of each other.
              echo ""
              _ros_ws_autosource() {
                [ "$PWD" = "''${_ros_ws_last_pwd:-}" ] && return
                _ros_ws_last_pwd="$PWD"

                local _v _pv
                for _v in AMENT_PREFIX_PATH CMAKE_PREFIX_PATH PATH PYTHONPATH LD_LIBRARY_PATH PKG_CONFIG_PATH; do
                  _pv="_ros_pristine_$_v"
                  export "$_v=''${!_pv}"
                done

                case "$PWD" in
                  *_ws)
                    center "Workspace detected - sourcing its overlay..."
                    if [ -f install/setup.bash ]; then
                      if source install/setup.bash; then
                        center "Sourced $PWD/install/setup.bash"
                      else
                        center "install/setup.bash failed - build it with"
                        center "'colcon build --symlink-install', then source"
                        center "it manually with 'source install/setup.bash'"
                      fi
                    elif [ -f install/local_setup.bash ]; then
                      if source install/local_setup.bash; then
                        center "Sourced $PWD/install/local_setup.bash"
                      else
                        center "install/local_setup.bash failed - build it with"
                        center "'colcon build --symlink-install', then source it"
                        center "manually with 'source install/local_setup.bash'"
                      fi
                    else
                      center "No install/setup.bash yet - build it with"
                      center "'colcon build --symlink-install', then source it"
                      center "manually with 'source install/setup.bash'"
                    fi
                    ;;
                esac
              }
              export -f _ros_ws_autosource
              PROMPT_COMMAND="_ros_ws_autosource''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
              _ros_ws_autosource

              # rviz2 needs no nixGL/OpenGL wrapper here: NixOS wires up
              # /run/opengl-driver system-wide, unlike plain Ubuntu+Nix setups.
              echo ""
              center "You can run your project using:"
              center "colcon build --symlink-install"
              center "rviz2"
              center "lsdev   (list connected serial/USB robot hardware)"
              center "colcon_cd <pkg>   (cd into a package, tab-completes)"
              center "colcon build --mixin release   (or debug, ccache, ...)"
              center "cd into any *_ws dir - its overlay auto-sources"
              echo "$BAR"
            '';
          };
          default = rbe-4540-ros2;
        };
      });
  nixConfig = {
    extra-substituters = [ "https://ros.cachix.org" ];
    extra-trusted-public-keys = [ "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" ];
  };
}
