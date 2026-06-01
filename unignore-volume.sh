#!/bin/bash
# Remove a volume from the ignore list so it'll be processed again.
set -uo pipefail

IGNORE_FILE="$HOME/.config/import-media/ignore-volumes.txt"

if [[ ! -f "$IGNORE_FILE" ]] || [[ ! -s "$IGNORE_FILE" ]]; then
  /usr/bin/osascript -e 'display dialog "無視リストは空です。" with title "Media Import" buttons {"OK"} default button "OK"' >/dev/null 2>&1
  exit 0
fi

# Build list from current ignore-volumes.txt (skip comments and blanks).
items=""
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  [[ "${line:0:1}" == "#" ]] && continue
  if [[ -z "$items" ]]; then
    items="\"$line\""
  else
    items="$items, \"$line\""
  fi
done < "$IGNORE_FILE"

if [[ -z "$items" ]]; then
  /usr/bin/osascript -e 'display dialog "無視リストは空です。" with title "Media Import" buttons {"OK"} default button "OK"' >/dev/null 2>&1
  exit 0
fi

chosen=$(/usr/bin/osascript <<APPLESCRIPT 2>/dev/null
set theList to {$items}
set userChoice to (choose from list theList with prompt "無視リストから外したいメディアを選んでください" with title "Media Import - 無視リストから削除" OK button name "削除" cancel button name "キャンセル")
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

# Remove matching line (exact match).
/usr/bin/grep -Fxv "$chosen" "$IGNORE_FILE" > "${IGNORE_FILE}.tmp" || true
/bin/mv "${IGNORE_FILE}.tmp" "$IGNORE_FILE"

echo "✅ '$chosen' を無視リストから削除しました"
/usr/bin/osascript -e "display notification \"$chosen を無視リストから削除\" with title \"Media Import\" sound name \"Glass\"" >/dev/null 2>&1 || true
