#!/bin/bash
# Show what was imported in past sessions. Lists all manifest files,
# lets the user pick one, then displays which files came from that import.
set -uo pipefail

MANIFEST_DIR="$HOME/Library/Logs/import-media-manifests"

if [[ ! -d "$MANIFEST_DIR" ]] || [[ -z "$(/bin/ls -A "$MANIFEST_DIR" 2>/dev/null)" ]]; then
  /usr/bin/osascript -e 'display dialog "取り込み履歴がまだありません。\n\nSDカードから1回でも取り込みが完了すると、ここから履歴を確認できるようになります。" with title "Media Import" buttons {"OK"} default button "OK" with icon note' >/dev/null 2>&1
  exit 0
fi

# Build a friendly list of manifests (newest first).
items=""
declare -a path_map=()
i=0
while IFS= read -r manifest; do
  [[ -z "$manifest" ]] && continue
  # Header parsing
  session_line=$(/usr/bin/grep '^# Session' "$manifest" 2>/dev/null | /usr/bin/head -1)
  volume_line=$(/usr/bin/grep '^# Volume' "$manifest" 2>/dev/null | /usr/bin/head -1)
  source_line=$(/usr/bin/grep '^# Source' "$manifest" 2>/dev/null | /usr/bin/head -1)
  imported_count=$(/usr/bin/grep -cv '^#\|^src	' "$manifest" 2>/dev/null || echo 0)

  session_when="${session_line#* : }"
  vol_name=$(/usr/bin/basename "${volume_line#* : }")
  src_name="${source_line#* : }"

  display="$session_when  [$src_name / $vol_name]  ${imported_count}件"
  path_map[i]="$manifest"
  i=$((i + 1))

  if [[ -z "$items" ]]; then
    items="\"$display\""
  else
    items="$items, \"$display\""
  fi
done < <(/bin/ls -t "$MANIFEST_DIR"/*.tsv 2>/dev/null)

if [[ -z "$items" ]]; then
  /usr/bin/osascript -e 'display dialog "取り込み履歴がまだありません。" with title "Media Import" buttons {"OK"}' >/dev/null 2>&1
  exit 0
fi

chosen=$(/usr/bin/osascript <<APPLESCRIPT 2>/dev/null
set theList to {$items}
set userChoice to (choose from list theList with prompt "確認したい取り込みセッションを選んでください" with title "Media Import - 取り込み履歴" OK button name "詳細を見る" cancel button name "キャンセル")
if userChoice is false then
  return ""
else
  return item 1 of userChoice as string
end if
APPLESCRIPT
)

if [[ -z "$chosen" ]]; then
  exit 0
fi

# Find the matching manifest by its display string.
selected_manifest=""
i=0
while IFS= read -r manifest; do
  [[ -z "$manifest" ]] && continue
  session_line=$(/usr/bin/grep '^# Session' "$manifest" 2>/dev/null | /usr/bin/head -1)
  volume_line=$(/usr/bin/grep '^# Volume' "$manifest" 2>/dev/null | /usr/bin/head -1)
  source_line=$(/usr/bin/grep '^# Source' "$manifest" 2>/dev/null | /usr/bin/head -1)
  imported_count=$(/usr/bin/grep -cv '^#\|^src	' "$manifest" 2>/dev/null || echo 0)
  session_when="${session_line#* : }"
  vol_name=$(/usr/bin/basename "${volume_line#* : }")
  src_name="${source_line#* : }"
  candidate="$session_when  [$src_name / $vol_name]  ${imported_count}件"
  if [[ "$candidate" == "$chosen" ]]; then
    selected_manifest="$manifest"
    break
  fi
done < <(/bin/ls -t "$MANIFEST_DIR"/*.tsv 2>/dev/null)

if [[ -z "$selected_manifest" ]]; then
  echo "選択されたセッションが見つかりませんでした。"
  exit 1
fi

echo "============================================"
echo "セッション詳細"
echo "============================================"
/usr/bin/head -5 "$selected_manifest"
echo
echo "============================================"
echo "取り込んだファイル"
echo "============================================"
# Skip header lines, show only dst paths.
/usr/bin/grep -v '^#\|^src	' "$selected_manifest" | /usr/bin/awk -F'\t' '{print $2}'
echo

# Ask what to do next.
action=$(/usr/bin/osascript <<APPLESCRIPT 2>/dev/null
set userChoice to (display dialog "このセッションで取り込んだファイルをどうしますか？" with title "Media Import" buttons {"閉じる", "Finderで開く", "TextEditで詳細を見る"} default button "Finderで開く")
return button returned of userChoice
APPLESCRIPT
)

case "$action" in
  *Finder*)
    # Open the common parent folder if possible (first file's dirname).
    first_dst=$(/usr/bin/grep -v '^#\|^src	' "$selected_manifest" | /usr/bin/awk -F'\t' '{print $2}' | /usr/bin/head -1)
    [[ -n "$first_dst" ]] && /usr/bin/open -R "$first_dst" 2>/dev/null
    ;;
  *TextEdit*)
    /usr/bin/open -a TextEdit "$selected_manifest"
    ;;
esac
