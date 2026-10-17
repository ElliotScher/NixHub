# shellcheck shell=bash
# Shared logic for mapping dev projects (identified by their git remote) to
# their devshell flake under dev/. Sourced by scripts/rebuild.sh (finds every
# project before switching), by the nixhubEnvrcs home-manager activation step
# in users/elliotscher/home.nix (writes each project's .envrc), and by
# scripts/test-dev-projects.sh.
#
# Needs git, find, awk and jq on PATH.

NIXHUB_STATE_DIR="$HOME/.local/state/nixhub"
NIXHUB_ENVRC_MARKER="# Managed by NixHub (users/elliotscher/dev-projects.nix) - rewritten on every rebuild, don't edit."

# Reduces any form of a git remote URL to a lowercase "owner/repo", so
# https://github.com/Owner/Repo.git, git@github.com:Owner/Repo and
# ssh://git@github.com:22/Owner/Repo/ all compare equal. The host is dropped -
# every mapped project lives on GitHub, and GitHub paths are case-insensitive.
normalize_remote() {
  local url=$1
  url=${url%/}
  url=${url%.git}
  case $url in
    *://*)
      url=${url#*://}
      url=${url#*@}
      url=${url#*/}
      ;;
    *:*)
      url=${url#*:}
      ;;
  esac
  printf '%s\n' "${url,,}"
}

# Prints "<normalized remote>\t<repo dir>" for every git repo under $1 that has
# an origin. Skips trees that only ever hold copies or tooling (Trash, caches,
# dependency/venv dirs) so stray clones there can't count as a project, and
# doesn't descend into a repo's own .git.
scan_repos() {
  local root=$1 gitpath dir url
  find "$root" \
    \( -name Trash -o -name .cache -o -name .local -o -name node_modules \
       -o -name .direnv -o -name .venv -o -name result -o -name target \) -prune \
    -o -name .git -prune -print 2>/dev/null |
    while IFS= read -r gitpath; do
      dir=${gitpath%/.git}
      url=$(git -C "$dir" config --get remote.origin.url 2>/dev/null) || continue
      printf '%s\t%s\n' "$(normalize_remote "$url")" "$dir"
    done
}

# resolve_projects KEYS_FILE SCAN_FILE
# KEYS_FILE holds one "owner/repo" key per line, SCAN_FILE is scan_repos
# output. Prints "<key>\t<dir>" for every key with exactly one matching repo;
# reports keys with zero or several matches on stderr and returns 1 if there
# were any.
resolve_projects() {
  local keys=$1 scan=$2 key status=0
  local -a matches
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    mapfile -t matches < <(awk -F'\t' -v k="${key,,}" '$1 == k { print $2 }' "$scan")
    case ${#matches[@]} in
      1)
        printf '%s\t%s\n' "$key" "${matches[0]}"
        ;;
      0)
        printf 'error: %s: no git repo with this remote found\n' "$key" >&2
        status=1
        ;;
      *)
        printf 'error: %s: found in %d places, remove or move all but one:\n' "$key" "${#matches[@]}" >&2
        printf '         %s\n' "${matches[@]}" >&2
        status=1
        ;;
    esac
  done < "$keys"
  return $status
}

# Prints "<key>\t<flake ref>" for every project in the manifest JSON, where the
# ref is "<flake dir under dev/>" plus "#<shell>" when a non-default devShell
# is selected.
manifest_refs() {
  jq -r '.projects | to_entries[]
    | [.key, (.value.flake + (if .value.shell then "#" + .value.shell else "" end))]
    | @tsv' "$1"
}

_is_managed_envrc() {
  [ -f "$1" ] && [ "$(head -n1 "$1")" = "$NIXHUB_ENVRC_MARKER" ]
}

# write_envrcs MANIFEST DIRENV_BIN
# Writes "use nixhub <ref>" into each project directory that rebuild resolved
# (see NIXHUB_STATE_DIR/dev-projects.resolved), re-checking each one's remote
# first so a stale location (plain nixos-rebuild after a move) is skipped with
# a warning rather than written into. Never creates directories, never touches
# an .envrc it didn't write, and removes .envrc files it wrote earlier for
# projects that have since moved or been dropped from the map.
write_envrcs() {
  local manifest=$1 direnv=$2
  local resolved="$NIXHUB_STATE_DIR/dev-projects.resolved"
  local pending="$NIXHUB_STATE_DIR/check-pending"
  local written="$NIXHUB_STATE_DIR/envrcs-written"
  local key ref dir url content old kept
  local -A ref_for=()
  local -a new_dirs=()

  if [ ! -f "$resolved" ]; then
    echo "nixhub: dev projects haven't been located yet - run 'rebuild' to write their .envrc files" >&2
    return 0
  fi
  if [ -f "$pending" ]; then
    rm -f "$pending"
  else
    echo "nixhub: this switch didn't go through 'rebuild', so dev projects weren't re-checked; reusing their last known locations" >&2
  fi

  while IFS=$'\t' read -r key ref; do
    ref_for[${key,,}]=$ref
  done < <(manifest_refs "$manifest")

  while IFS=$'\t' read -r key dir; do
    ref=${ref_for[${key,,}]:-}
    [ -n "$ref" ] || continue # dropped from the map since rebuild ran
    url=$(git -C "$dir" config --get remote.origin.url 2>/dev/null) || url=""
    if [ -z "$url" ] || [ "$(normalize_remote "$url")" != "${key,,}" ]; then
      echo "nixhub: $key is no longer at $dir - run 'rebuild' to find it" >&2
      continue
    fi
    if [ -e "$dir/.envrc" ] && ! _is_managed_envrc "$dir/.envrc"; then
      echo "nixhub: $dir/.envrc wasn't written by NixHub, leaving it alone" >&2
      continue
    fi
    content="$NIXHUB_ENVRC_MARKER"$'\n'"use nixhub $ref"
    if [ "$(cat "$dir/.envrc" 2>/dev/null)" != "$content" ]; then
      printf '%s\n' "$content" > "$dir/.envrc"
    fi
    "$direnv" allow "$dir/.envrc"
    new_dirs+=("$dir")
  done < "$resolved"

  if [ -f "$written" ]; then
    while IFS= read -r old; do
      kept=0
      for dir in "${new_dirs[@]}"; do
        [ "$dir" = "$old" ] && kept=1 && break
      done
      if [ $kept = 0 ] && _is_managed_envrc "$old/.envrc"; then
        rm -f "$old/.envrc"
      fi
    done < "$written"
  fi
  mkdir -p "$NIXHUB_STATE_DIR"
  if [ ${#new_dirs[@]} -gt 0 ]; then
    printf '%s\n' "${new_dirs[@]}" > "$written"
  else
    : > "$written"
  fi
}
