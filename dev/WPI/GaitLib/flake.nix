{
  description = "GaitLib (CVT swerve vendordep) Development Flake";

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
      # Like CodeCoach, the GaitLib repo carries no Nix files - its Gradle
      # (WPILib native-utils) build has to work as-is on Windows/macOS/Linux
      # and in CI - so every NixOS accommodation lives here.
      devShells = forEachSystem ({ pkgs, ... }:
        let
          # FHS loader path WPILib's prebuilt cross toolchains expect (Linux
          # hosts only - on macOS they're native binaries).
          fhsLoader =
            if pkgs.stdenv.hostPlatform.isAarch64
            then "/lib/ld-linux-aarch64.so.1"
            else "/lib64/ld-linux-x86-64.so.2";
        in
        rec {
          gaitlib = pkgs.mkShell {
            name = "gaitlib";

            # mkShell's stdenv already provides gcc + binutils: that's the host
            # compiler native-utils uses for the desktop (linuxx86-64) build and
            # the GoogleTest suite. The roboRIO / Linux ARM32 / ARM64 cross
            # toolchains are *not* from Nix - `./gradlew installRoboRioToolchain
            # installArm32Toolchain installArm64Toolchain` downloads WPILib's
            # prebuilt generic-Linux ones into ~/.gradle/toolchains, and they
            # only run because nix-ld is enabled system-wide (checked below).
            packages = [
              # GradleRIO / native-utils 2026 run on Gradle 8.14, which can't
              # parse class files from anything newer than JDK 24 - JDK 17 is
              # what WPILib 2026 ships and what CI uses.
              pkgs.jdk17
            ];

            # See the FRC 190 Robot_Code flake's env.JAVA_HOME comment - same
            # rationale: without it Gradle (and CLion's Gradle integration)
            # falls back to whatever JDK is ambient, here JDK 25, and fails.
            env.JAVA_HOME = "${pkgs.jdk17.home}";

            # See the FRC 190 Robot_Code flake's env.GRADLE_OPTS comment.
            env.GRADLE_OPTS = "-Dorg.gradle.console=rich";

            # nixpkgs' cc-wrapper injects hardening flags the WPILib build never
            # asks for. -D_FORTIFY_SOURCE in particular makes glibc emit a
            # "requires compiling with optimization" #warning on every -O0 debug
            # compile, which native-utils' warnings-as-errors turns into a
            # failed build. Disabling it all keeps the local desktop build's
            # flags matching what WPILib/CI pass.
            hardeningDisable = [ "all" ];

            shellHook = ''
              ${shellBanner {
                title = "Welcome to the GaitLib Development Environment";
                subtitle = "Using JDK 17 and $($CXX --version | head -n1).";
              }}
              echo ""

              ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                # WPILib's cross toolchains are dynamically linked against a
                # standard FHS loader - see the packages comment above.
                if [ -e ${fhsLoader} ]; then
                  center "nix-ld (for WPILib cross toolchains): OK"
                else
                  center "WARNING: ${fhsLoader} is missing -"
                  center "WPILib's roboRIO/ARM cross compilers won't run."
                  center "Enable programs.nix-ld in your host's NixOS config,"
                  center "then rebuild+switch."
                fi
                echo ""
              ''}

              center "You can run your project using:"
              center "./gradlew build"
              center "./gradlew build -Ponlylinuxathena"
              center "./gradlew installRoboRioToolchain"
              center "./gradlew installArm32Toolchain installArm64Toolchain"
              center "./gradlew publishToMavenLocal"
              echo "$BAR"
            '';
          };
          default = gaitlib;
        });
    };
}
