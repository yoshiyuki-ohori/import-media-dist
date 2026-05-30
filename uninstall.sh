#!/bin/bash
# Uninstall the media auto-import system.
# Leaves your imported videos and the cloned repo intact — only removes LaunchAgents.
set -e

IMPORT_PLIST="$HOME/Library/LaunchAgents/com.user.importmedia.plist"
UPDATE_PLIST="$HOME/Library/LaunchAgents/com.user.importmedia.update.plist"

launchctl unload "$IMPORT_PLIST" 2>/dev/null || true
launchctl unload "$UPDATE_PLIST" 2>/dev/null || true
rm -f "$IMPORT_PLIST" "$UPDATE_PLIST"
rm -f "$HOME/Library/Caches/import-media.pid"

echo "✅ アンインストール完了"
echo "  - LaunchAgent 削除済み"
echo "  - $HOME/Movies/ のファイルは残しています"
echo "  - $(cd "$(dirname "$0")" && pwd) (このリポジトリ) も残しています"
echo "  完全に削除したい場合は手動でこれらを削除してください。"
