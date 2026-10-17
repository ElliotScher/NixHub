{
  description = "CodeCoach Development Flake";

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
      # Everything here is NixOS-only plumbing. The CodeCoach repo itself
      # deliberately carries no Nix files - its pnpm-script build has to work
      # as-is on stock Windows/macOS/Linux - so every NixOS workaround lives
      # in this shell as an env var the project merely *honors* if present.
      devShells = forEachSystem ({ pkgs, ... }: rec {
        codecoach = pkgs.mkShell {
          name = "codecoach";

          packages = [
            pkgs.nodejs_22
            pkgs.pnpm
            # Both robot controller JDKs at once, unlike the FRC 190
            # Robot_Code flake's one-shell-per-platform split: CodeCoach's
            # build-runner tests and evals build roboRIO (JDK 17) *and*
            # SystemCore (JDK 25) fixture projects in the same session.
            pkgs.jdk17
            pkgs.jdk25
            # RobotPy fixtures - robotpy itself is pip-installed into a
            # fixture venv by the test setup, not provided by Nix.
            pkgs.python3
          ];

          # Per-version JDK homes, named to match what actions/setup-java
          # exports in CI (there with an _X64/_ARM64 suffix, which CodeCoach's
          # JDK resolver also accepts). The resolver picks one per project
          # from its target platform, so the ambient JAVA_HOME below is only
          # a fallback for tools that ignore the per-version vars.
          env.JAVA_HOME_17 = "${pkgs.jdk17.home}";
          env.JAVA_HOME_25 = "${pkgs.jdk25.home}";
          env.JAVA_HOME = "${pkgs.jdk17.home}";

          # See the FRC 190 Robot_Code flake's env.GRADLE_OPTS comment - same
          # rationale, for the fixture builds run through a plain pipe.
          env.GRADLE_OPTS = "-Dorg.gradle.console=rich";

          # npm's prebuilt Electron is a generic-Linux binary that can't run on
          # NixOS, so skip the download and point Electron at nixpkgs' build.
          env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
          env.ELECTRON_OVERRIDE_DIST_PATH = "${pkgs.electron}/libexec/electron";

          shellHook = ''
            # Same problem as Electron for @vscode/test-electron's downloaded
            # VS Code - reuse the system one (installed via home.nix) instead
            # of pulling a second unfree copy into this shell's closure.
            if [ -z "''${CODECOACH_VSCODE_EXECUTABLE:-}" ] && command -v code >/dev/null 2>&1; then
              export CODECOACH_VSCODE_EXECUTABLE="$(readlink -f "$(command -v code)")"
            fi

            ${shellBanner {
              title = "Welcome to the CodeCoach Dev Environment";
              subtitle = "Using Node.js $(node --version), pnpm $(pnpm --version), JDK 17 + 25.";
            }}
            echo ""

            if [ -f "package.json" ]; then
              # Automatically install/sync node_modules from pnpm-lock.yaml
              if [ ! -d "node_modules" ]; then
                center "Installing dependencies..."
                pnpm install
              elif [ "pnpm-lock.yaml" -nt "node_modules" ]; then
                center "pnpm-lock.yaml updated. Reinstalling dependencies..."
                pnpm install
                touch node_modules
              else
                center "Dependencies are up-to-date."
              fi

              echo ""
              center "You can run your project using:"
              center "pnpm build"
              center "pnpm test"
              center "pnpm dev:vscode"
              center "pnpm evals"
            else
              center "No project checked out here yet. Clone it first:"
              center "git clone https://github.com/ElliotScher/CodeCoach.git ."
            fi
            echo "$BAR"
          '';
        };
        default = codecoach;
      });
    };
}
