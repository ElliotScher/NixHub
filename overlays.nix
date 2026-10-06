[
  # download-cdn.jetbrains.com 404s on the toolbox tarball nixpkgs pins,
  # but download.jetbrains.com still serves the identical file (same
  # fixed-output hash). Unfree, so cache.nixos.org can't substitute it.
  # Drop once nixpkgs bumps jetbrains-toolbox.
  (final: prev: {
    jetbrains-toolbox = prev.jetbrains-toolbox.override {
      fetchzip = args: prev.fetchzip (args // {
        url = builtins.replaceStrings
          [ "download-cdn.jetbrains.com" ] [ "download.jetbrains.com" ] args.url;
      });
    };
  })
]
