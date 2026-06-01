#!/bin/bash
# Pop up a Finder folder picker and remember the chosen destination
# in ~/.config/import-media/dest-base.txt. The main import script reads from there.
set -euo pipefail

CONFIG_DIR="$HOME/.config/import-media"
DEST_FILE="$CONFIG_DIR/dest-base.txt"
mkdir -p "$CONFIG_DIR"

current=""
[[ -f "$DEST_FILE" ]] && current=$(/usr/bin/head -1 "$DEST_FILE" 2>/dev/null)

prompt_text="動画の保存先フォルダを選んでください。"
[[ -n "$current" ]] && prompt_text="$prompt_text\n\n現在: $current"

# AppleScript folder picker. Returns the POSIX path or empty if cancelled.
chosen=$(/usr/bin/osascript <<APPLESCRIPT 2>/dev/null || true
try
  set chosenFolder to choose folder with prompt "$prompt_text"
  return POSIX path of chosenFolder
on error
  return ""
end try
APPLESCRIPT
)

if [[ -z "$chosen" ]]; then
  echo "キャンセルされました。設定変更なし。"
  exit 0
fi

# Strip trailing slash.
chosen="${chosen%/}"
printf '%s\n' "$chosen" > "$DEST_FILE"

echo "✅ 保存先を更新しました:"
echo "    $chosen"
echo
echo "次回の取り込みからこの場所に保存されます。"

/usr/bin/osascript -e "display notification \"保存先: $chosen\" with title \"Media Import\" subtitle \"設定変更完了\" sound name \"Glass\"" >/dev/null 2>&1 || true
