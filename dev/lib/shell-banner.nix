# Shared devShell welcome banner: prints a "=" bar, a centered title, another
# bar, and an optional centered subtitle line. Both the bar width and the
# padding are computed at shell startup (not hand-typed), so the bar always
# matches the longest of title/subtitle regardless of how long that text
# ends up being (including subtitles with runtime substitutions like
# `$(node --version)`).
{ title, subtitle ? null, margin ? 4 }:
''
  TITLE_LEN=$(printf '%s' "${title}" | wc -c)
  ${if subtitle != null then ''SUBTITLE_LEN=$(printf '%s' "${subtitle}" | wc -c)'' else "SUBTITLE_LEN=0"}
  BAR_WIDTH=$(( TITLE_LEN > SUBTITLE_LEN ? TITLE_LEN : SUBTITLE_LEN ))
  BAR_WIDTH=$(( BAR_WIDTH + ${toString margin} ))
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
