# NixHub

Single flake covering every machine's full NixOS system (packages, GNOME
desktop, home-manager dotfiles) plus standalone development-environment
flakes (`Acadia_AI_E26/`, etc.). Cloning this repo and running one command
reproduces a whole machine.

## Layout

```
NixHub/
  flake.nix               # inputs + auto-discovers hosts/ as nixosConfigurations
  bootstrap.sh             # new-machine setup script, exposed as `nix run .#bootstrap`
  HOSTNAMES.md              # ordered hostname sequence (see below)
  common/
    configuration.nix       # system config shared by every host
  home/
    elliotscher.nix          # home-manager config shared by every host
  hosts/
    <name>/
      configuration.nix      # this host's system deltas
      hardware-configuration.nix  # machine-generated, never hand-edited
      home.nix                 # this host's home-manager deltas
```

`common/configuration.nix` and `home/elliotscher.nix` hold everything that
applies to every machine. `hosts/<name>/` holds only what's specific to one
machine - typically nothing at all beyond hardware detection, until a
specific host needs to deviate from the shared config.

## Overriding shared config per-host

Every overridable value in `common/configuration.nix` and
`home/elliotscher.nix` is wrapped in `lib.mkDefault`. That gives it low
priority, so a plain assignment in a host's own `configuration.nix` or
`home.nix` silently wins - no conflict, no need for `lib.mkForce`. For
example, to change the timezone on just one host:

```nix
# hosts/<name>/configuration.nix
{ config, pkgs, lib, inputs, ... }:
{
  time.timeZone = "America/Los_Angeles";
}
```

List-valued options (`environment.systemPackages`, `home.packages`,
`users.users.elliotscher.packages`, `users.users.elliotscher.extraGroups`,
etc.) are deliberately left *unwrapped* in the shared files. Lists from
multiple modules at the same priority concatenate rather than conflict, so a
host can add to these lists with a plain assignment of its own instead of
replacing them:

```nix
# hosts/<name>/configuration.nix
environment.systemPackages = with pkgs; [ someExtraTool ];
```

If you need a value shared by *some* hosts but not all (not "the one host"
tier, not "every host" tier), add a new file under `common/` (e.g.
`common/laptop.nix`) and list it in the `modules` for just the hosts that
need it, in `flake.nix`.

## Hostnames

Machines are named after Quenya (Elvish) numerals, spelled without
diacritics since NixOS hostnames only allow ASCII letters, digits, hyphens,
and underscores (`mine`, `atta`, `nelde`, `canta`, ...). See `HOSTNAMES.md`
for the full ordered list.

A name is picked by taking the first entry in `HOSTNAMES.md` that doesn't
already have a matching `hosts/<name>/` directory. Once a name is assigned,
it's permanent - `HOSTNAMES.md` can be freely edited (reordered, appended
to) afterward without any risk, since assignment is based on which
directories actually exist, not on the file's exact contents at any given
moment. Append more numerals to the list whenever you're running low.

## Setting up a new machine

After installing NixOS (or on an already-running system), run:

```
nix run github:ElliotScher/NixHub#bootstrap
```

On a completely fresh install, flakes aren't enabled yet, so the very first
invocation needs the experimental features passed explicitly:

```
nix --extra-experimental-features "nix-command flakes" run github:ElliotScher/NixHub#bootstrap
```

This clones the repo (if not already present) to
`~/Documents/Development/NixHub`, picks the next unused hostname, generates
that machine's `hardware-configuration.nix`, scaffolds empty
`hosts/<name>/configuration.nix` and `home.nix` files, and commits + pushes
the new host to GitHub. It prints the exact rebuild command to run once
you've reviewed the scaffolded files:

```
sudo nixos-rebuild switch --flake ~/Documents/Development/NixHub#<name>
```

The script doesn't run the rebuild itself, so you get a chance to look over
what was generated (and add any host-specific config) first.

Note: pushing requires git to already be authenticated against GitHub (via
`gh auth login` or an SSH key) - on a genuinely first-ever machine, before
this repo's own home-manager config (which sets up the `gh` credential
helper) has ever been applied, that push may fail. If it does, the script
still leaves you with a local commit; authenticate and push it manually.

## Tests

```
nix flake check
```

runs everything below in one command:

- **Evaluation** - every `nixosConfigurations.<name>` and other flake output
  is evaluated for type errors, invalid option values, and `mkDefault`
  conflicts. Free and fast; the baseline sanity check.
- **`checks.system-<name>`** - builds that host's full bootable system
  closure (`config.system.build.toplevel`) - GNOME, all packages,
  home-manager activation - without touching any real machine. Catches
  build failures evaluation alone won't (e.g. a package that fails to
  build). One of these exists per host in `hosts/`.
- **`checks.pick-hostname-logic`** - a pure, sandboxed test of the
  hostname-assignment logic in `scripts/pick-hostname.sh`
  (`scripts/test-pick-hostname.sh`), covering the no-hosts-used, some-used,
  all-used, and mid-list-insertion cases.
- **`checks.vm-smoke-test`** - boots `common/configuration.nix` +
  `home/elliotscher.nix` (the config shared by every host, independent of
  any one host's real hardware) in a NixOS VM and asserts the system
  reaches `multi-user.target`, the `elliotscher` user and its packages
  exist, home-manager activation completed, and GDM reaches
  `graphical.target`.

The individual checks can also be run on their own, e.g.
`nix build .#checks.x86_64-linux.vm-smoke-test -L`. The system-closure and
VM checks are meaningfully slower than plain evaluation (several minutes),
since they build real system closures and boot a VM.

## Rebuilding an existing machine

```
sudo nixos-rebuild switch --flake ~/Documents/Development/NixHub#<name>
```

No symlink to `/etc/nixos` is used - the repo's location is the single
source of truth, and the `--flake` path always points directly at it.
