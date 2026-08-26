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
      in {
        devShells = rec {
          rbe-4540-ros2 = pkgs.mkShell {
            name = "rbe-4540-ros2";
            packages = [
              pkgs.neovim
              pkgs.colcon
              pkgsPlain.python3Packages.colcon-cd
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
                 turtlesim
                ];
              })
            ];

            shellHook = ''
              # `ls -l` of any connected serial/USB robot hardware, and their
              # perms - handy since NixOS grants /dev/ttyUSB*, /dev/ttyACM*
              # access via a system-level group (see below), not a package.
              alias lsdev="ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null"

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

              # Auto-source the workspace overlay so locally-built packages are
              # on the path without a manual `source install/setup.bash` every
              # time. Only runs once at shell entry, so re-`source` (or re-enter
              # the shell) after a `colcon build` that creates install/ for the
              # first time.
              echo ""
              if [ -f install/setup.bash ]; then
                source install/setup.bash
                center "Sourced install/setup.bash"
              else
                center "No install/setup.bash yet - run 'colcon build --symlink-install'"
              fi

              # rviz2 needs no nixGL/OpenGL wrapper here: NixOS wires up
              # /run/opengl-driver system-wide, unlike plain Ubuntu+Nix setups.
              echo ""
              center "You can run your project using:"
              center "colcon build --symlink-install"
              center "rviz2"
              center "lsdev   (list connected serial/USB robot hardware)"
              center "colcon_cd <pkg>   (cd into a package, tab-completes)"
              center "colcon build --mixin release   (or debug, ccache, ...)"
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
