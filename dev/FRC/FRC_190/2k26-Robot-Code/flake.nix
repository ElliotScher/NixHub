{
  description = "2026 FRC Robot Code Development Flake";

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
        # Environment for building/deploying the 2026 robot code (build.gradle
        # targets Java 17; GradleRIO/vendor deps and the wrapper itself
        # bootstrap everything else via ./gradlew)
        robot-code = pkgs.mkShell {
          name = "2k26-robot-code-nix";

          packages = [
            pkgs.jdk17
          ];

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the 2026 FRC 190 Robot Code Development Environment";
              subtitle = "Using JDK 17.";
            }}
            echo ""
            center "You can run your project using:"
            center "./gradlew build"
            center "./gradlew deploy"
            center "./gradlew simulateJava"
            echo "$BAR"
          '';
        };
        default = robot-code;
      });
    };
}
