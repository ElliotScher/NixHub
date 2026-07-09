#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: pick-hostname.sh <HOSTNAMES.md> <hosts-dir>" >&2
  exit 2
fi

hostnames_file="$1"
hosts_dir="$2"

while IFS= read -r candidate; do
  if [ ! -d "$hosts_dir/$candidate" ]; then
    echo "$candidate"
    exit 0
  fi
done < <(grep -E '^[0-9]+\.' "$hostnames_file" | awk '{print $2}')

echo "No unused hostnames left in $hostnames_file - add more and re-run." >&2
exit 1
