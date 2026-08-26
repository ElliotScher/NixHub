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

      shellBanner = import ../../../lib/shell-banner.nix;
    in
    {
      # One devshell per robot controller platform - not tied to one
      # season's project directory, so a new season's repo reuses whichever
      # of these matches its controller. VS Code's own JDK 21 (needed only
      # to host redhat.java's language server) is handled separately and
      # statically in home.nix, deliberately kept out of both shells here:
      # a project opened via either shell can only ever be built by its own
      # matching JDK, never by 21.
      devShells = forEachSystem ({ pkgs, ... }: rec {
        # roboRIO-based robot code (2k26 and earlier)
        roborio = pkgs.mkShell {
          name = "frc-190-roborio";

          packages = [
            pkgs.jdk17
          ];

          # mkShell puts jdk17 on PATH but never sets JAVA_HOME - without it,
          # vscode-gradle's Gradle Tooling API client falls back to whatever
          # JDK redhat.java uses to host its own language server (JDK 21,
          # statically pinned in home.nix), so gradle build/import silently
          # runs on the wrong JDK. Exporting it here lets `code` (launched
          # via `nix develop ... --command code`) and everything it spawns
          # inherit the correct one.
          env.JAVA_HOME = "${pkgs.jdk17.home}";

          # Gradle only emits its colored "rich" console (progress bars,
          # colored task status) when it detects stdout is a real terminal.
          # The WPILib/Gradle VS Code extensions run gradlew through a plain
          # pipe rather than a pty for their build/deploy tasks, so that
          # autodetection falls back to plain text - forcing rich mode here
          # restores the colored output those extensions inherit via `code`.
          env.GRADLE_OPTS = "-Dorg.gradle.console=rich";

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the FRC 190 RoboRIO Development Environment";
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

        # SystemCore-based robot code
        systemcore = pkgs.mkShell {
          name = "frc-190-systemcore";

          packages = [
            pkgs.jdk25
          ];

          # See the roborio shell's env.JAVA_HOME comment above - same
          # rationale, just for JDK 25.
          env.JAVA_HOME = "${pkgs.jdk25.home}";

          # See the roborio shell's env.GRADLE_OPTS comment above.
          env.GRADLE_OPTS = "-Dorg.gradle.console=rich";

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the FRC 190 SystemCore Development Environment";
              subtitle = "Using JDK 25.";
            }}
            echo ""
            center "You can run your project using:"
            center "./gradlew build"
            center "./gradlew deploy"
            center "./gradlew simulateJava"
            echo "$BAR"
          '';
        };

        default = roborio;
      });
    };
}
