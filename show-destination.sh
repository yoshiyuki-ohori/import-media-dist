#!/bin/bash
# Show the current import destination, list per-source file counts,
# and open the folder in Finder.
set -uo pipefail

CONFIG_DIR="$HOME/.config/import-media"
DEST_FILE="$CONFIG_DIR/dest-base.txt"
CONFIG_FILE="$CONFIG_DIR/config.sh"

DEST="$HOME/Movies"   # default

# Honor dest-base.txt (set by set-destination.sh).
if [[ -f "$DEST_FILE" ]]; then
  saved=$(/usr/bin/head -1 "$DEST_FILE" 2>/dev/null | /usr/bin/sed 's:/*$::')
  [[ -n "$saved" && -d "$saved" ]] && DEST="$saved"
fi

# Honor config.sh DEST_BASE_OVERRIDE (advanced).
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE" 2>/dev/null || true
  [[ -n "${DEST_BASE_OVERRIDE:-}" ]] && DEST="$DEST_BASE_OVERRIDE"
fi

cat <<EOF
=========================================
📂 保存先
=========================================
$DEST
=========================================
EOF

if [[ ! -d "$DEST" ]]; then
  echo "⚠️  フォルダがまだ存在しません（まだ取り込みが一度も走ってないかも）"
  exit 1
fi

echo "ソース別ファイル数:"
echo
shopt -s nullglob 2>/dev/null || true
for d in "$DEST"/*/; do
  [[ -d "$d" ]] || continue
  count=$(/usr/bin/find "$d" -type f \
    \( -iname '*.MP4' -o -iname '*.MOV' -o -iname '*.M4V' \
    -o -iname '*.LRV' -o -iname '*.INSV' -o -iname '*.AVI' \
    -o -iname '*.MKV' -o -iname '*.MTS' -o -iname '*.M2TS' \) \
    2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    size=$(/usr/bin/du -sh "$d" 2>/dev/null | /usr/bin/awk '{print $1}')
    printf "  📁 %-30s %5s 件   %s\n" "$(/usr/bin/basename "$d")" "$count" "$size"
  fi
done

echo
echo "Finderで保存先を開きます..."
/usr/bin/open "$DEST"
