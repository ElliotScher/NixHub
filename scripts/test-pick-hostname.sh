#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pick="$script_dir/pick-hostname.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

run_case() {
  local desc="$1"
  local names="$2"
  local existing="$3"
  local expect_exit="$4"
  local expect_stdout="$5"

  local tmp
  tmp="$(mktemp -d)"

  local -a name_arr existing_arr
  read -ra name_arr <<< "$names"
  read -ra existing_arr <<< "$existing"

  local i=1
  local n
  for n in "${name_arr[@]}"; do
    echo "$i. $n" >> "$tmp/HOSTNAMES.md"
    i=$((i + 1))
  done

  mkdir -p "$tmp/hosts"
  local e
  for e in "${existing_arr[@]}"; do
    [ -z "$e" ] || mkdir -p "$tmp/hosts/$e"
  done

  local actual_stdout actual_exit
  actual_stdout="$(bash "$pick" "$tmp/HOSTNAMES.md" "$tmp/hosts" 2>/dev/null)" && actual_exit=0 || actual_exit=$?

  rm -rf "$tmp"

  if [ "$actual_exit" -ne "$expect_exit" ]; then
    fail "$desc: expected exit $expect_exit, got $actual_exit"
  fi

  if [ "$expect_exit" -eq 0 ] && [ "$actual_stdout" != "$expect_stdout" ]; then
    fail "$desc: expected '$expect_stdout', got '$actual_stdout'"
  fi

  echo "PASS: $desc"
}

run_case "no hosts used yet - picks first name" \
  "mine atta nelde" "" 0 "mine"

run_case "first two used - picks third" \
  "mine atta nelde" "mine atta" 0 "nelde"

run_case "name inserted mid-list is still picked over later-used ones" \
  "mine atta nelde canta" "mine nelde canta" 0 "atta"

run_case "all names used - fails with no output" \
  "mine atta" "mine atta" 1 ""

echo "All pick-hostname tests passed."
