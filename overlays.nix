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

  # VSCode 1.144 moved its bundled ripgrep from node_modules/@vscode/ripgrep
  # to node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/<platform>,
  # so nixpkgs' postPatch (which swaps it for pkgs.ripgrep) fails on `rm`.
  # Point it at the new location. replaceStrings is a no-op once nixpkgs
  # updates the path itself - drop this overlay then.
  (final: prev: {
    vscode = prev.vscode.overrideAttrs (old: {
      postPatch = builtins.replaceStrings
        [ "resources/app/node_modules/@vscode/ripgrep/bin/rg" ]
        [ "resources/app/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg" ]
        old.postPatch;
    });
  })
]
