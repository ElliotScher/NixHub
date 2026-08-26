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

        shellBanner = import ../../lib/shell-banner.nix;
      in {
        devShells = rec {
          rbe-4540-ros2 = pkgs.mkShell {
            name = "rbe-4540-ros2";
            packages = [
              pkgs.neovim
              pkgs.colcon
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
                ];
              })
            ];

            shellHook = ''
              # `ls -l` of any connected serial/USB robot hardware, and their
              # perms - handy since NixOS grants /dev/ttyUSB*, /dev/ttyACM*
              # access via a system-level group (see below), not a package.
              alias lsdev="ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null"

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
