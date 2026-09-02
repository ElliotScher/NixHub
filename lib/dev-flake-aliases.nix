# Recursively scans `devDir` for subdirectories that directly contain a
# flake.nix, and returns a `{ <dirname> = "nix develop <devRoot>/<relpath>"; }`
# attrset - one shell alias per development flake, keyed by that flake
# directory's own name, so dropping a new flake under dev/ gets it an alias
# for free on the next `nixos-rebuild switch`, with no matching edit needed
# here.
#
# `devDir` is a path (so the recursive `builtins.readDir` walk stays inside
# the flake's own pure-eval-visible source tree), while `devRoot` is a plain
# string holding the *live* checkout's absolute path - using a path there
# instead would point every alias at the immutable /nix/store copy of dev/
# rather than the working tree these flakes are actually edited in.
{ lib, devDir, devRoot }:
let
  findFlakeDirs = relPath: dir:
    let
      entries = builtins.readDir dir;
    in
    if (entries."flake.nix" or null) == "regular" then
      [ relPath ]
    else
      lib.concatMap
        (name: findFlakeDirs (if relPath == "" then name else "${relPath}/${name}") (dir + "/${name}"))
        (lib.attrNames (lib.filterAttrs (_: type: type == "directory") entries));

  flakeRelPaths = findFlakeDirs "" devDir;

  # Two flakes nested under different parents but sharing a directory name
  # would otherwise silently collide on the same alias - fail loudly instead
  # of picking one at random.
  duplicates = lib.filterAttrs (_: paths: builtins.length paths > 1)
    (lib.groupBy baseNameOf flakeRelPaths);
in
if duplicates != { } then
  throw "dev-flake-aliases: duplicate devshell directory names, rename one: ${builtins.toJSON duplicates}"
else
  lib.listToAttrs (map
    (relPath: {
      name = baseNameOf relPath;
      value = "nix develop ${devRoot}/${relPath}";
    })
    flakeRelPaths)
