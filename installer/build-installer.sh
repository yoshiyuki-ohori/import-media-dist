#!/bin/bash
# Build the double-clickable installer + uninstaller apps from their .applescript sources.
#
#   ./installer/build-installer.sh [output-dir]
#
# Produces in <output-dir> (default: ~/Desktop):
#   動画取り込みインストーラ.app
#   動画取り込みアンインストーラ.app
# Distribute via the shared Drive or AirDrop. First launch on each Mac needs a
# one-time "システム設定 → プライバシーとセキュリティ → このまま開く" (unsigned / Gatekeeper).
set -euo pipefail

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUT_DIR="${1:-$HOME/Desktop}"
mkdir -p "$OUT_DIR"

build() {
  local src="$HERE/$1" app="$OUT_DIR/$2"
  [[ -f "$src" ]] || { echo "❌ ソースが見つかりません: $src" >&2; exit 1; }
  rm -rf "$app"
  /usr/bin/osacompile -o "$app" "$src"
  echo "✅ ビルド完了: $app"
}

build installer.applescript   "動画取り込みインストーラ.app"
build uninstaller.applescript "動画取り込みアンインストーラ.app"
echo "   配布: 共有ドライブか AirDrop で各メンバーへ。"
echo "   初回のみ システム設定 → プライバシーとセキュリティ → このまま開く（未署名アプリのため）。"
