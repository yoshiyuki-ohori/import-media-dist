#!/bin/bash
# Build the double-clickable installer app from installer.applescript.
#
#   ./installer/build-installer.sh [output-dir]
#
# Produces "<output-dir>/動画取り込みインストーラ.app" (default: ~/Desktop).
# Distribute that .app via the shared Drive or AirDrop. First launch on each
# Mac needs a one-time right-click → 開く (unsigned app / Gatekeeper).
set -euo pipefail

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC="$HERE/installer.applescript"
OUT_DIR="${1:-$HOME/Desktop}"
APP="$OUT_DIR/動画取り込みインストーラ.app"

[[ -f "$SRC" ]] || { echo "❌ ソースが見つかりません: $SRC" >&2; exit 1; }
mkdir -p "$OUT_DIR"

rm -rf "$APP"
/usr/bin/osacompile -o "$APP" "$SRC"

# Mark as an agent-less foreground app (default osacompile output is fine).
echo "✅ ビルド完了: $APP"
echo "   配布: この .app を共有ドライブか AirDrop で各メンバーへ。"
echo "   初回のみ 右クリック → 開く（未署名アプリのため）。"
