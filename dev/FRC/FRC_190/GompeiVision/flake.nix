{
  description = "GompeiVision Development Flake";

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
      devShells = forEachSystem ({ pkgs, ... }: rec {
        # Editing environment for GompeiVision. Real builds deliberately stay
        # in the repo's own Dockerfile.X86/Dockerfile.ARM images (as its
        # README recommends): third_party/CMakeLists.txt links allwpilib C++
        # 2025.1.1 and openpnp-capture from hard-coded /usr/local paths, and
        # neither library is in nixpkgs. This shell provides the toolchain,
        # clangd and the headers nixpkgs *does* have (so IntelliSense resolves
        # most includes), plus the docker CLI for the container build -
        # rootless Docker itself is enabled in hosts/atta/configuration.nix.
        gompeivision = pkgs.mkShell {
          name = "gompeivision";

          packages = [
            pkgs.cmake
            pkgs.ninja
            pkgs.gnumake
            pkgs.gcc
            pkgs.clang-tools # clangd + clang-format (repo ships a .clang-format)
            pkgs.gdb
            pkgs.pkg-config

            pkgs.opencv
            pkgs.apriltag
            pkgs.httplib
            pkgs.nlohmann_json
            pkgs.protobuf
            pkgs.ffmpeg.dev
            pkgs.systemd.dev # libudev
            pkgs.zstd

            pkgs.docker-client
            pkgs.docker-buildx
          ];

          env.CMAKE_EXPORT_COMPILE_COMMANDS = "1";

          shellHook = ''
            ${shellBanner {
              title = "Welcome to the GompeiVision Development Environment";
              subtitle = "Editing natively, building in Docker.";
            }}
            echo ""
            if [ -f Dockerfile.X86 ]; then
              center "Build the image once:"
              center "docker build -f Dockerfile.X86 -t gompeivision-build ."
              center "Then build inside it:"
              center "docker run --rm -v \"\$PWD\":/src -w /src gompeivision-build \\"
              center "  sh -c 'cmake -B build && cmake --build build'"
            else
              center "No project checked out here yet. Clone it first:"
              center "git clone https://github.com/Team-190/GompeiVision.git ."
            fi
            echo "$BAR"
          '';
        };
        default = gompeivision;
      });
    };
}
