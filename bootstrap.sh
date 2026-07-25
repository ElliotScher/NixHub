REPO_URL="https://github.com/ElliotScher/NixHub.git"
REPO_DIR="${NIXHUB_DIR:-$HOME/Documents/NixHub}"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning NixHub into $REPO_DIR..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR" || exit 1

# Authenticate GitHub CLI up front - this is what the later `git push` (both
# bootstrap's own commit and everything after) relies on, and on a genuinely
# fresh machine nothing has configured git credentials yet. `gh auth login`
# also offers to wire itself up as git's credential helper, so plain `git
# push` works immediately afterward too, not just `gh` commands.
if ! gh auth status &>/dev/null; then
  echo
  echo "GitHub CLI isn't authenticated yet - this is needed to push commits."
  gh auth login
fi

NEW_HOST="$(bash scripts/pick-hostname.sh HOSTNAMES.md hosts)"

echo "Assigning hostname: $NEW_HOST"

# ---------------------------------------------------------------------------
# Interactive prompts - collect every setting needed to scaffold this host
# before touching the filesystem, so nixos-generate-config isn't run only to
# have the user abandon partway through answering questions.
# ---------------------------------------------------------------------------

echo
read -r -p "Set up this host as headless (no desktop environment)? [y/N] " headless_answer
if [[ "$headless_answer" =~ ^[Yy]$ ]]; then
  HEADLESS=1
else
  HEADLESS=0
fi

mapfile -t AVAILABLE_USERS < <(
  for dir in users/*/; do
    user="$(basename "$dir")"
    if [ -f "users/$user/home.nix" ]; then
      echo "$user"
    fi
  done
)

echo
echo "Available users: ${AVAILABLE_USERS[*]}"
while true; do
  read -r -p "Users to set up on this host (space-separated, default: elliotscher): " users_answer
  if [ -z "$users_answer" ]; then
    HOST_USERS=("elliotscher")
  else
    read -r -a HOST_USERS <<< "$users_answer"
  fi

  unknown_users=()
  for user in "${HOST_USERS[@]}"; do
    if [ ! -f "users/$user/home.nix" ]; then
      unknown_users+=("$user")
    fi
  done

  if [ "${#unknown_users[@]}" -eq 0 ]; then
    break
  fi
  echo "Unknown user(s): ${unknown_users[*]} - no matching users/<name>/home.nix. Available: ${AVAILABLE_USERS[*]}" >&2
done

echo
read -r -p "Timezone for this host (blank to use the shared default): " timezone_answer

HOST_DIR="hosts/$NEW_HOST"
mkdir -p "$HOST_DIR/home"

SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

sudo nixos-generate-config --dir "$SCRATCH_DIR"
cp "$SCRATCH_DIR/hardware-configuration.nix" "$HOST_DIR/hardware-configuration.nix"

CONFIG_EXTRA=""
if [ "$HEADLESS" -eq 1 ]; then
  CONFIG_EXTRA+="
  # Headless host - no desktop environment.
  services.xserver.enable = false;
  services.displayManager.gdm.enable = false;
  services.desktopManager.gnome.enable = false;
  services.gnome.core-apps.enable = false;
  programs.dconf.enable = false;
"
fi
if [ -n "$timezone_answer" ]; then
  CONFIG_EXTRA+="
  time.timeZone = \"$timezone_answer\";
"
fi

cat > "$HOST_DIR/configuration.nix" <<EOF
{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific system overrides for $NEW_HOST go here.
  # networking.hostName is set automatically from this directory's name.
  # Anything in ../../common/configuration.nix marked with lib.mkDefault can
  # be overridden with a plain assignment.
$CONFIG_EXTRA}
EOF

{
  printf '['
  for user in "${HOST_USERS[@]}"; do
    printf ' "%s"' "$user"
  done
  printf ' ]\n'
} > "$HOST_DIR/users.nix"

HOME_EXTRA=""
if [ "$HEADLESS" -eq 1 ]; then
  HOME_EXTRA="
  # Headless host - no desktop environment.
  gtk.enable = false;
  qt.enable = false;
  dconf.enable = false;
  programs.vscode.enable = false;
"
fi

for user in "${HOST_USERS[@]}"; do
  cat > "$HOST_DIR/home/$user.nix" <<EOF
{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific home-manager overrides for $user on $NEW_HOST go here.
  # Anything in ../../../users/$user/home.nix marked with lib.mkDefault can
  # be overridden with a plain assignment.
$HOME_EXTRA}
EOF
done

git add "$HOST_DIR"
git -c user.name="ElliotScher" -c user.email="ecscher84@gmail.com" commit -m "Add host $NEW_HOST"

echo
read -r -p "Push $NEW_HOST to origin now? [y/N] " push_answer
if [[ "$push_answer" =~ ^[Yy]$ ]]; then
  if git push; then
    echo "Pushed $NEW_HOST to origin."
  else
    echo "WARNING: git push failed (auth not set up yet?). The commit is local only - push manually once you're authenticated." >&2
  fi
else
  echo "Skipped. The commit is local only - push manually later with: git push"
fi

REBUILD_CMD="sudo nixos-rebuild switch --flake $REPO_DIR#$NEW_HOST"

echo
echo "Review the generated files in $HOST_DIR before rebuilding."
read -r -p "Run '$REBUILD_CMD' now? [y/N] " rebuild_answer
if [[ "$rebuild_answer" =~ ^[Yy]$ ]]; then
  sudo nixos-rebuild switch --flake "$REPO_DIR#$NEW_HOST"
else
  echo "Skipped. Run this when you're ready:"
  echo
  echo "  $REBUILD_CMD"
  echo
fi
