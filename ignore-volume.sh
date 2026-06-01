#!/bin/bash
# List currently mounted external volumes and let the user pick one to add
# to the ignore list (so future imports skip it silently).
set -uo pipefail

IGNORE_FILE="$HOME/.config/import-media/ignore-volumes.txt"
mkdir -p "$(/usr/bin/dirname "$IGNORE_FILE")"
/usr/bin/touch "$IGNORE_FILE"

# Build the list of candidate volumes (skip macOS system volumes).
items=""
declare -a name_map=()
i=0
for v in /Volumes/*/; do
  v="${v%/}"
  name=$(/usr/bin/basename "$v")
  case "$name" in
    "Macintosh HD"|"Macintosh HD - Data"|"Recovery"|"Preboot"|"VM"|"Update"|"xarts"|"iSCPreboot")
      continue ;;
  esac
  [[ -d "$v/System" ]] && continue

  # Annotate if already in ignore list.
  display="$name"
  if /usr/bin/grep -Fxq "$name" "$IGNORE_FILE" 2>/dev/null; then
    display="$name (既に無視中)"
  fi

  name_map[i]="$name"
  i=$((i + 1))

  if [[ -z "$items" ]]; then
    items="\"$display\""
  else
    items="$items, \"$display\""
  fi
done

if [[ -z "$items" ]]; then
  /usr/bin/osascript -e 'display dialog "接続中の外部メディアが見つかりません。\n\nSDカードや外付けSSDを差してから実行してください。" with title "Media Import" buttons {"OK"} default button "OK" with icon caution' >/dev/null 2>&1
  exit 0
fi

chosen=$(/usr/bin/osascript <<APPLESCRIPT 2>/dev/null
set theList to {$items}
set userChoice to (choose from list theList with prompt "自動取り込みから除外したいメディアを選んでください" with title "Media Import - 無視リストに追加" OK button name "無視に追加" cancel button name "キャンセル")
if userChoice is false then
  return ""
else
  return item 1 of userChoice as string
end if
APPLESCRIPT
)

if [[ -z "$chosen" ]]; then
  echo "キャンセル"
  exit 0
fi

# Strip the "(既に無視中)" annotation if present.
real_name="${chosen% (既に無視中)*}"

if /usr/bin/grep -Fxq "$real_name" "$IGNORE_FILE" 2>/dev/null; then
  /usr/bin/osascript -e "display dialog \"$real_name は既に無視リストに入っています。\" with title \"Media Import\" buttons {\"OK\"} default button \"OK\"" >/dev/null 2>&1
  exit 0
fi

# Append to ignore list.
printf '%s\n' "$real_name" >> "$IGNORE_FILE"
echo "✅ '$real_name' を無視リストに追加しました"
echo "→ $IGNORE_FILE"
/usr/bin/osascript -e "display notification \"$real_name を無視リストに追加しました\" with title \"Media Import\" sound name \"Glass\"" >/dev/null 2>&1 || true
