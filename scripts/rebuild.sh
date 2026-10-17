# shellcheck shell=bash
# Wraps `nixos-rebuild` so that every dev project in
# users/elliotscher/dev-projects.nix is located (by its git remote, anywhere
# under the search root) *before* anything is switched - a project that can't
# be found, or is found in more than one place, fails the rebuild here instead
# of silently losing its .envrc. The locations found are handed to the
# nixhubEnvrcs activation step through NIXHUB_STATE_DIR.
#
# Usage: rebuild [switch|boot|test|build|dry-activate] [--nixhub DIR]
#                [--skip-project-check] [extra nixos-rebuild args...]
#
# Exposed as `nix run .#rebuild` (and the `rebuild` shell alias); the shared
# helpers come from scripts/dev-projects-lib.sh, sourced via
# NIXHUB_DEV_PROJECTS_LIB which the flake sets to its store path.

# shellcheck source=/dev/null
source "${NIXHUB_DEV_PROJECTS_LIB:-$(dirname "${BASH_SOURCE[0]}")/dev-projects-lib.sh}"

die() {
  echo "rebuild: $*" >&2
  exit 1
}

usage() {
  echo "Usage: rebuild [switch|boot|test|build|dry-activate] [--nixhub DIR]"
  echo "               [--skip-project-check] [extra nixos-rebuild args...]"
}

is_nixhub() {
  [ -f "$1/flake.nix" ] && [ -d "$1/dev" ] && [ -d "$1/hosts" ]
}

action=switch
nixhub=""
skip_check=0
extra_args=()
if [ $# -gt 0 ]; then
  case $1 in
    switch|boot|test|build|dry-activate)
      action=$1
      shift
      ;;
  esac
fi
while [ $# -gt 0 ]; do
  case $1 in
    --nixhub)
      [ $# -ge 2 ] || die "--nixhub needs a directory"
      nixhub=$2
      shift 2
      ;;
    --skip-project-check)
      skip_check=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

# Where NixHub lives is never hard-coded: an explicit --nixhub wins, then the
# checkout you're standing in, then wherever the last rebuild ran from. The
# result is recorded for the `use nixhub` direnv helper and the alias, so
# moving NixHub only takes one `nix run <new path>#rebuild`.
if [ -z "$nixhub" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top" ] && is_nixhub "$top"; then
    nixhub=$top
  elif [ -f "$NIXHUB_STATE_DIR/root" ]; then
    nixhub=$(cat "$NIXHUB_STATE_DIR/root")
  fi
fi
if [ -z "$nixhub" ] || ! is_nixhub "$nixhub"; then
  die "can't find the NixHub checkout - run this from inside it, or pass --nixhub DIR"
fi
nixhub=$(realpath "$nixhub")
mkdir -p "$NIXHUB_STATE_DIR"
printf '%s\n' "$nixhub" > "$NIXHUB_STATE_DIR/root"

host=$(hostname)
user=$(id -un)

if [ $skip_check = 0 ]; then
  tmp=$(mktemp -d)
  # Not an EXIT trap: the final `exec` below would skip it.
  cleanup() { rm -rf "$tmp"; }

  # Read the map from the configuration about to be built, not from whatever
  # the currently-running generation has - so the check always matches what
  # this switch will apply.
  nix eval --raw \
    "$nixhub#nixosConfigurations.\"$host\".config.home-manager.users.\"$user\".xdg.configFile.\"nixhub/dev-projects.json\".text" \
    > "$tmp/manifest.json" ||
    { cleanup; die "couldn't evaluate the dev project map for $host/$user (see the error above)"; }

  search_root=$(jq -r '.searchRoot' "$tmp/manifest.json")
  jq -r '.projects | keys[]' "$tmp/manifest.json" > "$tmp/keys"
  echo "rebuild: locating $(wc -l < "$tmp/keys") dev projects under $search_root..."

  failed=0
  while IFS=$'\t' read -r key ref; do
    if [ ! -f "$nixhub/dev/${ref%%#*}/flake.nix" ]; then
      echo "error: $key: its devshell flake dev/${ref%%#*} doesn't exist in $nixhub" >&2
      failed=1
    fi
  done < <(manifest_refs "$tmp/manifest.json")

  scan_repos "$search_root" > "$tmp/scan"
  resolve_projects "$tmp/keys" "$tmp/scan" > "$tmp/resolved" || failed=1

  if [ $failed != 0 ]; then
    echo >&2
    echo "rebuild: aborted before switching - fix the projects above, or edit users/elliotscher/dev-projects.nix" >&2
    echo "         (to rebuild anyway, without updating any .envrc: rebuild --skip-project-check)" >&2
    cleanup
    exit 1
  fi

  previous="$NIXHUB_STATE_DIR/dev-projects.resolved"
  while IFS=$'\t' read -r key dir; do
    old=""
    [ -f "$previous" ] && old=$(awk -F'\t' -v k="$key" '$1 == k { print $2 }' "$previous")
    if [ -n "$old" ] && [ "$old" != "$dir" ]; then
      echo "  moved  $key -> $dir"
    else
      echo "  ok     $key  $dir"
    fi
  done < "$tmp/resolved"

  mv "$tmp/resolved" "$previous"
  cleanup
  # Only for actions that activate (now or at next boot) - tells the
  # nixhubEnvrcs step these locations came from this run's check.
  case $action in
    switch|boot|test) touch "$NIXHUB_STATE_DIR/check-pending" ;;
  esac
fi

case $action in
  build|dry-activate)
    exec nixos-rebuild "$action" --flake "$nixhub#$host" "${extra_args[@]}"
    ;;
  *)
    status=0
    sudo nixos-rebuild "$action" --flake "$nixhub#$host" "${extra_args[@]}" || status=$?
    # nixhubEnvrcs consumes this flag when it runs, but home-manager's
    # activation is skipped entirely when nothing in it changed - don't let
    # a leftover flag make a later plain nixos-rebuild look checked.
    rm -f "$NIXHUB_STATE_DIR/check-pending"
    exit $status
    ;;
esac
