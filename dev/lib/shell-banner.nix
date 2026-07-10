# Shared devShell welcome banner: prints a "=" bar, a centered title, another
# bar, and an optional centered subtitle line. Padding is computed at shell
# startup (not hand-typed), so lines stay centered under the bars regardless
# of how long the title/subtitle text ends up being.
{ title, subtitle ? null, width ? 60 }:
''
  BAR_WIDTH=${toString width}
  BAR=$(printf '=%.0s' $(seq 1 $BAR_WIDTH))

  center() {
    text="$1"
    len=$(printf '%s' "$text" | wc -c)
    pad=$(( (BAR_WIDTH - len) / 2 ))
    if [ "$pad" -lt 0 ]; then pad=0; fi
    printf '%*s%s\n' "$pad" "" "$text"
  }

  echo "$BAR"
  center "${title}"
  echo "$BAR"
  ${if subtitle != null then ''center "${subtitle}"'' else ""}
''
