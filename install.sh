#!/bin/bash
# Media auto-import installer.
# Run once per Mac. Generates per-user LaunchAgents with no hardcoded paths.
#
# Usage:
#   ./install.sh           interactive (prompts to open System Settings)
#   ./install.sh --quiet   non-interactive (used by update.sh)
set -e

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

# Resolve install location from this script's own path — no hardcoded user paths.
INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_PATH="$INSTALL_DIR/import-media.sh"
UPDATE_PATH="$INSTALL_DIR/update.sh"

# Per-user destination paths derived from $HOME.
LA_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"
MOVIES_DIR="$HOME/Movies"

IMPORT_PLIST="$LA_DIR/com.user.importmedia.plist"
UPDATE_PLIST="$LA_DIR/com.user.importmedia.update.plist"

mkdir -p "$LA_DIR" "$LOG_DIR" "$MOVIES_DIR"
chmod +x "$INSTALL_DIR"/*.sh

# ---------- Generate import LaunchAgent ----------
cat > "$IMPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.importmedia</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Volumes</string>
        <string>$HOME/Downloads</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/import-media.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/import-media.err.log</string>
</dict>
</plist>
EOF

# ---------- Generate auto-update LaunchAgent (daily 4 AM) ----------
cat > "$UPDATE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.importmedia.update</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$UPDATE_PATH</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/import-media-update.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/import-media-update.err.log</string>
</dict>
</plist>
EOF

# ---------- (Re-)load LaunchAgents ----------
launchctl unload "$IMPORT_PLIST" 2>/dev/null || true
launchctl unload "$UPDATE_PLIST" 2>/dev/null || true
launchctl load -w "$IMPORT_PLIST"
launchctl load -w "$UPDATE_PLIST"

if [[ $QUIET -eq 1 ]]; then
  exit 0
fi

cat <<EOF

==========================================
✅ インストール完了
==========================================
スクリプト場所  : $SCRIPT_PATH
保存先          : $MOVIES_DIR/<ソース>/<年>/<日付>/<機種>/
ログ            : $LOG_DIR/import-media.log
自動アップデート : 毎日 04:00 に git pull
==========================================

次の手順:
  1. システム設定 → プライバシーとセキュリティ → フルディスクアクセス
  2. '+' ボタン → Cmd+Shift+G → /bin → 'bash' を選択 → 追加
  3. SDカードを差すか AirDrop で動画を受信 → 自動取り込み開始

EOF

if [[ -t 0 ]]; then
  read -r -p "今すぐシステム設定を開きますか？ (y/N) " yn
  if [[ "$yn" =~ ^[Yy] ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  fi
fi
