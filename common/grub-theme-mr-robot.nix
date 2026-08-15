{ stdenvNoCC, fetchFromGitHub, fetchurl, imagemagick, librsvg }:

let
  # NixOS/nixos-artwork - the official Nix snowflake logo, used to render a
  # proper icons/nixos.png below (upstream only ships icons for other distros).
  nixosSnowflake = fetchurl {
    url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/9d2cdedd73d64a068214482902adea3d02783ba8/logo/nix-snowflake-colours.svg";
    sha256 = "1cifj774r4z4m856fva1mamnpnhsjl44kw3asklrc57824f5lyz3";
  };
in
stdenvNoCC.mkDerivation {
  pname = "grub-theme-mr-robot";
  version = "0-unstable-2026-08-15";

  src = fetchFromGitHub {
    owner = "johdasgran";
    repo = "mr-robot-theme";
    rev = "6f40221ff51fcf7dd9f63391ad7ce4ac9ef53650";
    sha256 = "0f0iqm4hf2m4b9cl4jw9xnwq8w48xm33x9wjjlrbfj9dzpg9kyj8";
  };

  dontBuild = true;
  nativeBuildInputs = [ imagemagick librsvg ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r . "$out/"
    rm -f "$out/install.sh"

    # Upstream leaves this at the default "stretch", which distorts the
    # 1980x1080 background to whatever the display's exact aspect ratio is.
    # "crop" scales to fill without warping, cropping any overflow instead.
    sed -i '/^desktop-image:/a desktop-image-scale-method: "crop"' "$out/theme.txt"

    rsvg-convert -w 128 -h 128 ${nixosSnowflake} -o nixos-128.png
    magick nixos-128.png -resize 32x32 -gravity center -background none -extent 32x32 "$out/icons/nixos.png"

    runHook postInstall
  '';
}
