#!/usr/bin/env bash
# Tests for scripts/dev-projects-lib.sh: remote normalization, repo scanning,
# project resolution and .envrc writing. Pure and sandboxable (only needs
# git, jq, awk and a writable $HOME) - run by the dev-projects-logic flake check.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# shellcheck source=dev-projects-lib.sh
source "$script_dir/dev-projects-lib.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_eq() {
  [ "$2" = "$3" ] || fail "$1: expected '$3', got '$2'"
}

# --- normalize_remote --------------------------------------------------------
for url in \
  https://github.com/Owner/Repo.git \
  https://github.com/Owner/Repo \
  https://github.com/owner/repo/ \
  https://user@github.com/Owner/Repo.git \
  git@github.com:Owner/Repo.git \
  git@github.com:Owner/Repo \
  ssh://git@github.com/Owner/Repo.git \
  ssh://git@github.com:22/Owner/Repo/
do
  expect_eq "normalize $url" "$(normalize_remote "$url")" "owner/repo"
done

# --- scan_repos --------------------------------------------------------------
root="$tmp/root"
mkrepo() { # mkrepo DIR [REMOTE]
  mkdir -p "$1"
  git -C "$1" init -q
  if [ $# -ge 2 ]; then git -C "$1" remote add origin "$2"; fi
}
mkrepo "$root/Development/A"                https://github.com/Me/Alpha.git
mkrepo "$root/Development/nested/B"         git@github.com:Me/Beta.git
mkrepo "$root/Development/Dup1"             https://github.com/Me/Dup
mkrepo "$root/Elsewhere/Dup2"               git@github.com:me/dup.git
mkrepo "$root/Development/NoRemote"
mkrepo "$root/Development/A/node_modules/x" https://github.com/Me/Gamma.git
mkrepo "$root/.local/share/Trash/files/C"   https://github.com/Me/Gamma.git

scan_repos "$root" | sort > "$tmp/scan"
expect_eq "scan finds repos with an origin, skipping pruned dirs" "$(cut -f1 "$tmp/scan" | tr '\n' ' ')" \
  "me/alpha me/beta me/dup me/dup "
grep -q "$root/Development/nested/B" "$tmp/scan" || fail "scan should report repo dirs"

# --- resolve_projects --------------------------------------------------------
printf '%s\n' "Me/Alpha" "me/BETA" > "$tmp/keys"
resolve_projects "$tmp/keys" "$tmp/scan" > "$tmp/out" 2> "$tmp/err" || fail "unique keys should resolve: $(cat "$tmp/err")"
expect_eq "resolve output" "$(cat "$tmp/out")" \
  "Me/Alpha	$root/Development/A
me/BETA	$root/Development/nested/B"

printf '%s\n' "Me/Alpha" "Me/Missing" "Me/Dup" > "$tmp/keys"
if resolve_projects "$tmp/keys" "$tmp/scan" > "$tmp/out" 2> "$tmp/err"; then
  fail "missing and duplicate keys should fail"
fi
grep -q "Me/Missing: no git repo" "$tmp/err" || fail "missing key should be reported"
grep -q "Me/Dup: found in 2 places" "$tmp/err" || fail "duplicate key should be reported"
grep -q "$root/Elsewhere/Dup2" "$tmp/err" || fail "duplicate report should list paths"
expect_eq "resolvable keys still printed" "$(cut -f1 "$tmp/out")" "Me/Alpha"

# --- write_envrcs ------------------------------------------------------------
cat > "$tmp/manifest.json" <<'EOF'
{ "searchRoot": "unused",
  "projects": {
    "Me/Alpha": { "flake": "Personal/Alpha" },
    "Me/Beta":  { "flake": "WPI/Beta", "shell": "ros" } } }
EOF
# Absolute shebang: the Nix build sandbox has no /usr/bin/env.
cat > "$tmp/direnv" <<EOF
#!$BASH
echo "\$@" >> "$tmp/direnv.log"
EOF
chmod +x "$tmp/direnv"
mkdir -p "$NIXHUB_STATE_DIR"

# No resolved file yet: warn, write nothing.
write_envrcs "$tmp/manifest.json" "$tmp/direnv" 2> "$tmp/err"
grep -q "haven't been located" "$tmp/err" || fail "should warn when nothing resolved yet"
[ ! -e "$root/Development/A/.envrc" ] || fail "nothing should be written before rebuild"

printf 'Me/Alpha\t%s\nMe/Beta\t%s\n' "$root/Development/A" "$root/Development/nested/B" \
  > "$NIXHUB_STATE_DIR/dev-projects.resolved"
touch "$NIXHUB_STATE_DIR/check-pending"
write_envrcs "$tmp/manifest.json" "$tmp/direnv" 2> "$tmp/err"
[ ! -s "$tmp/err" ] || fail "fresh check should not warn: $(cat "$tmp/err")"
[ ! -e "$NIXHUB_STATE_DIR/check-pending" ] || fail "check-pending should be consumed"
expect_eq "alpha envrc" "$(tail -n1 "$root/Development/A/.envrc")" "use nixhub Personal/Alpha"
expect_eq "beta envrc uses shell attr" "$(tail -n1 "$root/Development/nested/B/.envrc")" "use nixhub WPI/Beta#ros"
grep -q "allow $root/Development/A/.envrc" "$tmp/direnv.log" || fail "envrc should be direnv-allowed"

# A plain nixos-rebuild after the project moved: warn, skip, clean up the old file.
mv "$root/Development/nested/B" "$root/Development/B-moved"
write_envrcs "$tmp/manifest.json" "$tmp/direnv" 2> "$tmp/err"
grep -q "weren't re-checked" "$tmp/err" || fail "bypassed rebuild should warn"
grep -q "Me/Beta is no longer at" "$tmp/err" || fail "moved project should be reported"
[ ! -e "$root/Development/nested/B" ] || fail "must not recreate a moved project's directory"

# A project that has its own, hand-written .envrc is left alone.
printf 'use flake .\n' > "$root/Development/Dup1/.envrc"
printf 'Me/Dup\t%s\n' "$root/Development/Dup1" > "$NIXHUB_STATE_DIR/dev-projects.resolved"
jq '.projects["Me/Dup"] = { "flake": "X" }' "$tmp/manifest.json" > "$tmp/m2.json"
touch "$NIXHUB_STATE_DIR/check-pending"
write_envrcs "$tmp/m2.json" "$tmp/direnv" 2> "$tmp/err"
grep -q "wasn't written by NixHub" "$tmp/err" || fail "unmanaged envrc should be reported"
expect_eq "unmanaged envrc untouched" "$(cat "$root/Development/Dup1/.envrc")" "use flake ."
[ ! -e "$root/Development/A/.envrc" ] || fail "envrc of a project no longer resolved should be removed"

echo "All dev-projects tests passed."
