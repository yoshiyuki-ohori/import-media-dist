#!/bin/bash
# Manually trigger an import from a chosen mounted volume.
# Bypasses the should_ignore_volume blacklist and any cached signature —
# meaning the dialog will pop up even for "permanently ignored" volumes.
set -uo pipefail

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SIG_DIR="$HOME/Library/Caches/import-media-vols"

# Collect candidate volume names (skip system / boot volumes).
items=""
for v in /Volumes/*/; do
  v="${v%/}"
  name=$(/usr/bin/basename "$v")
  case "$name" in
    "Macintosh HD"|"Macintosh HD - Data"|"Recovery"|"Preboot"|"VM"|"Update"|"xarts"|"iSCPreboot")
      continue ;;
  esac
  [[ -d "$v/System" ]] && continue
  if [[ -z "$items" ]]; then
    items="\"$name\""
  else
    items="$items, \"$name\""
  fi
done

if [[ -z "$items" ]]; then
  /usr/bin/osascript -e 'display dialog "接続中の外部メディアが見つかりません。SDカードや外付けディスクを差してから実行してください。" with title "Media Import" buttons {"OK"} default button "OK" with icon caution' >/dev/null 2>&1
  exit 0
fi

# Show a chooser dialog.
chosen=$(/usr/bin/osascript <<APPLESCRIPT 2>/dev/null
set theList to {$items}
set userChoice to (choose from list theList with prompt "今すぐ取り込むメディアを選んでください" with title "Media Import" OK button name "取り込む" cancel button name "キャンセル")
if userChoice is false then
  return ""
else
  return item 1 of userChoice as string
end if
APPLESCRIPT
)

if [[ -z "$chosen" ]]; then
  echo "キャンセルされました。"
  exit 0
fi

volpath="/Volumes/$chosen"
echo "取り込み開始: $volpath"

# Wipe any cached signature for this volume so the import logic actually proceeds.
safe=$(echo "$chosen" | /usr/bin/tr -c '[:alnum:]._-' '_')
/bin/rm -f "$SIG_DIR/$safe"

# Run the main script in "force" mode — bypasses ignore list and scans only this volume.
FORCE_VOLUME="$volpath" /bin/bash "$INSTALL_DIR/import-media.sh"
