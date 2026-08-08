{
  description = "FRC 190 Robot Code Development Flake";

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
      # General-purpose devshell for whichever robot code repo is current
      # (2k26-Robot-Code today) - not tied to one season's project
      # directory, so a new season's repo can reuse this same flake without
      # needing its own copy. Bump the JDK versions here if a future season
      # changes requirements.
      devShells = forEachSystem ({ pkgs, ... }: rec {
        # JDK 17 for the robot code itself (WPILib/GradleRIO's current
        # target; ./gradlew bootstraps everything else), plus JDK 21, which
        # redhat.java's language server needs just to run (separate from
        # what the project itself builds with). JAVA_HOME stays on 17 - what
        # gradlew/toolchain resolution actually compiles against - while
        # JDK_HOME is 21, the language server's own boot JVM.
        robot-code = pkgs.mkShell {
          name = "frc-190-robot-code-nix";

          packages = [
            pkgs.jdk17
            pkgs.jdk21
          ];

          env = {
            JAVA_HOME = "${pkgs.jdk17.home}";
            JDK_HOME = "${pkgs.jdk21.home}";
          };

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the FRC 190 Robot Code Development Environment";
              subtitle = "Using JDK 17 (JDK 21 also available, for the Java language server).";
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
