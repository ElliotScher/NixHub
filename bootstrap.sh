REPO_URL="https://github.com/ElliotScher/NixHub.git"
REPO_DIR="${NIXHUB_DIR:-$HOME/Documents/Development/NixHub}"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning NixHub into $REPO_DIR..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR" || exit 1

NEW_HOST="$(bash scripts/pick-hostname.sh HOSTNAMES.md hosts)"

echo "Assigning hostname: $NEW_HOST"

HOST_DIR="hosts/$NEW_HOST"
mkdir -p "$HOST_DIR/home"

SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

sudo nixos-generate-config --dir "$SCRATCH_DIR"
cp "$SCRATCH_DIR/hardware-configuration.nix" "$HOST_DIR/hardware-configuration.nix"

cat > "$HOST_DIR/configuration.nix" <<EOF
{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific system overrides for $NEW_HOST go here.
  # networking.hostName is set automatically from this directory's name.
  # Anything in ../../common/configuration.nix marked with lib.mkDefault can
  # be overridden with a plain assignment.
}
EOF

cat > "$HOST_DIR/users.nix" <<EOF
[ "elliotscher" ]
EOF

cat > "$HOST_DIR/home/elliotscher.nix" <<EOF
{ config, pkgs, lib, inputs, ... }:

{
  # Host-specific home-manager overrides for elliotscher on $NEW_HOST go
  # here. Anything in ../../../users/elliotscher/home.nix marked with
  # lib.mkDefault can be overridden with a plain assignment.
}
EOF

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
