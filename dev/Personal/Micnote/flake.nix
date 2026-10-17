{
  description = "Micnote Development Flake";

  # Implements Micnote's own spec for this file: docs/PLAN.md §6.3 and
  # docs/stages/00a-dev-environment.md §4.5 in the Micnote repo. The repo
  # itself deliberately contains no Nix files - this flake is personal.

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Pinned Zephyr SDK (arm-zephyr-eabi). Nordic's toolchain-manager
    # binaries don't run on NixOS, so this replaces them.
    zephyr-nix = {
      url = "github:nix-community/zephyr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zephyr-nix }:
    let
      # Supported systems for development
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # Helper function to generate attributes for each system
      forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f rec {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true; # nrfutil, segger-jlink, nrfconnect, Android SDK
            android_sdk.accept_license = true;
            segger-jlink.acceptLicense = true;
          };
        };
        zephyr = zephyr-nix.packages.${system};
      });

      shellBanner = import ../../lib/shell-banner.nix;
    in
    {
      devShells = forEachSystem ({ pkgs, zephyr, ... }:
        let
          # NCS 3.x targets Zephyr SDK 0.17.x. Only the Arm toolchain is
          # fetched - the plain `sdk` attribute ships with no toolchains,
          # and sdkFull pulls every architecture.
          zephyrSdk = zephyr.sdk-0_17.override { targets = [ "arm-zephyr-eabi" ]; };
          llvm = pkgs.llvmPackages_latest;

          # Native libraries the Flutter Linux desktop build links against.
          flutterLinuxLibs = [
            pkgs.gtk3
            pkgs.libsecret
            pkgs.libepoxy
            pkgs.xz
          ];

          commonPackages = [
            # Firmware (Zephyr / nRF Connect SDK)
            zephyrSdk
            zephyr.hosttools-nix
            pkgs.cmake
            pkgs.ninja
            pkgs.dtc
            pkgs.gperf
            pkgs.ccache
            pkgs.python3
            pkgs.uv
            pkgs.nrfutil
            # Headless = just libjlinkarm + udev rules: enough for nrfutil
            # (and pyocd) to flash over J-Link. The full segger-jlink pack
            # (JLinkExe, JLinkGDBServer for `west debug --runner jlink`)
            # pulls in segger-jlink-qt4, which nixpkgs flags insecure; swap
            # it in here, with that package in permittedInsecurePackages,
            # if J-Link GDB debugging is ever needed.
            pkgs.segger-jlink-headless
            pkgs.python3Packages.pyocd
            pkgs.nrfconnect

            # Core (libmicnote, C++23)
            llvm.clang
            llvm.clang-tools # clangd, clang-tidy, clang-format
            llvm.lld
            llvm.compiler-rt # libFuzzer
            # GCC comes from mkShell's stdenv (the newest nixpkgs ships,
            # above the spec's gcc >= 14 floor) - an explicit gccNN here
            # would only be shadowed by it on PATH.
            pkgs.pkg-config
            pkgs.protobuf # protoc, for nanopb regeneration
            pkgs.dbus
            pkgs.bluez
            pkgs.vulkan-headers
            pkgs.vulkan-loader
            pkgs.shaderc
            pkgs.whisper-cpp
            pkgs.llama-cpp

            # App (Flutter)
            pkgs.flutter
          ] ++ flutterLinuxLibs;

          commonShellHook = ''
            export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
            export ZEPHYR_SDK_INSTALL_DIR="${zephyrSdk}"
            # Zephyr's CMake finds the toolchain through the variable above;
            # this just makes arm-zephyr-eabi-gcc/-gdb callable directly too.
            export PATH="${zephyrSdk}/arm-zephyr-eabi/bin:$PATH"
            export CMAKE_EXPORT_COMPILE_COMMANDS=1
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (flutterLinuxLibs ++ [ pkgs.vulkan-loader ])}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            # nixpkgs' flutter wrapper sets up its own SDK root; a stale
            # FLUTTER_ROOT from elsewhere would override it.
            unset FLUTTER_ROOT
            # Stops `flutter doctor` complaining about a missing Chrome -
            # web isn't a Micnote target.
            export CHROME_EXECUTABLE=""

            # 1. Python venv for west and the NCS requirements (uv-managed,
            #    not zephyr-nix's pythonEnv: that one follows upstream
            #    Zephyr's requirements, NCS has its own).
            if [ ! -d ".venv" ]; then
              center "Creating virtual environment with west..."
              uv venv --python "${pkgs.python3}/bin/python3"
              VIRTUAL_ENV=.venv uv pip install west
            fi
            source .venv/bin/activate

            # 2. Once `west update` has fetched Zephyr and NCS, install their
            #    requirements - re-run only when those files change.
            _reqs=""
            for _f in external/zephyr/scripts/requirements.txt external/nrf/scripts/requirements.txt; do
              [ -f "$_f" ] && _reqs="$_reqs $_f"
            done
            if [ -n "$_reqs" ]; then
              _hash=$(cat $_reqs | sha256sum | cut -d' ' -f1)
              if [ "$(cat .venv/.micnote-reqs-hash 2>/dev/null)" != "$_hash" ]; then
                center "Zephyr/NCS requirements changed. Installing..."
                uv pip install $(printf -- '-r %s ' $_reqs) && echo "$_hash" > .venv/.micnote-reqs-hash
              fi
            fi
            unset _f _reqs _hash

            echo ""
            if [ -d firmware ] && [ ! -d .west ]; then
              center "Fetch the firmware dependencies with:"
              center "west init -l firmware && west update"
            elif [ ! -d firmware ]; then
              center "Repo not scaffolded yet (Phase 0b) - firmware/, core/ and app/"
              center "will pick up this toolchain once they exist."
            fi
            if [ -x scripts/doctor.sh ]; then
              scripts/doctor.sh --quiet || center "scripts/doctor.sh reported problems (see above)."
            fi
          '';

          androidSdk = (pkgs.androidenv.composeAndroidPackages {
            includeNDK = true;
            # TODO: pin platform, build-tools and NDK versions from
            # tools/versions.env once Phase 0a adds it.
            platformVersions = [ "35" ];
            buildToolsVersions = [ "35.0.0" ];
          }).androidsdk;
        in
        rec {
          # Firmware + core + desktop app.
          micnote = pkgs.mkShell {
            name = "micnote";
            packages = commonPackages;
            shellHook = ''
              ${shellBanner {
                title = "Welcome to the Micnote Development Environment";
                subtitle = "Zephyr SDK ${zephyrSdk.version}, LLVM ${llvm.clang.version}, Flutter ${pkgs.flutter.version}.";
              }}
              ${commonShellHook}
              echo "$BAR"
            '';
          };

          # micnote plus the Android SDK/NDK for the mobile app.
          android = pkgs.mkShell {
            name = "micnote-android";
            packages = commonPackages ++ [ androidSdk pkgs.jdk17 ];
            env = {
              ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
              ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
              JAVA_HOME = "${pkgs.jdk17.home}";
            };
            shellHook = ''
              ${shellBanner {
                title = "Welcome to the Micnote Android Development Environment";
                subtitle = "Everything in the default shell, plus the Android SDK/NDK.";
              }}
              for _ndk in "$ANDROID_HOME"/ndk/*; do export ANDROID_NDK_ROOT="$_ndk"; done
              unset _ndk
              ${commonShellHook}
              echo "$BAR"
            '';
          };

          # PCB and enclosure work - kept separate since it's large and
          # unrelated to the code.
          hardware = pkgs.mkShell {
            name = "micnote-hardware";
            packages = [
              pkgs.kicad
              pkgs.freecad
              pkgs.openscad
            ];
            shellHook = ''
              ${shellBanner {
                title = "Welcome to the Micnote Hardware Environment";
                subtitle = "KiCad, FreeCAD and OpenSCAD.";
              }}
              echo "$BAR"
            '';
          };

          default = micnote;
        });
    };
}
