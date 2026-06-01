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
APPS_DIR="$HOME/Applications"
APP_BUNDLE="$APPS_DIR/MediaImport.app"
APP_EXEC="$APP_BUNDLE/Contents/MacOS/MediaImport"

IMPORT_PLIST="$LA_DIR/com.user.importmedia.plist"
UPDATE_PLIST="$LA_DIR/com.user.importmedia.update.plist"

mkdir -p "$LA_DIR" "$LOG_DIR" "$MOVIES_DIR" "$APP_BUNDLE/Contents/MacOS"
# Pre-create source folders so the structure is visible in Finder from day one,
# even before the first import.
mkdir -p "$MOVIES_DIR/DJI" "$MOVIES_DIR/GoPro" "$MOVIES_DIR/iPhone" "$MOVIES_DIR/Downloads"
chmod +x "$INSTALL_DIR"/*.sh

# Per-user config (lives outside the repo, survives git pull updates).
CONFIG_DIR="$HOME/.config/import-media"
CONFIG_FILE="$CONFIG_DIR/config.sh"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<'EOF'
# import-media personal config — edited only locally, NOT updated by git pull.
# Uncomment lines to enable.

# Change where imported videos are stored.
# Example: a Google Drive folder for cloud sync.
# DEST_BASE_OVERRIDE="$HOME/Library/CloudStorage/GoogleDrive-YOUR_EMAIL/My Drive/Videos"

# Always ignore specific external volumes (your work SSDs, backup drives, etc.).
# Edit the case to add as many as you want, or wipe it for no ignores.
should_ignore_volume() {
  case "$1" in
    # "BackupSSD"|"WorkDrive") return 0 ;;
    *) return 1 ;;
  esac
}
EOF
  echo "✏️  Personal config template created at: $CONFIG_FILE"
fi

# ---------- Generate wrapper .app bundle ----------
# macOS won't let you grant Full Disk Access to /bin/bash directly on recent versions,
# so we wrap our script inside a .app bundle that can be FDA-granted via Finder drag.
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MediaImport</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.mediaimport</string>
    <key>CFBundleName</key>
    <string>MediaImport</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST_EOF

cat > "$APP_EXEC" <<EOF
#!/bin/bash
exec "$SCRIPT_PATH" "\$@"
EOF
chmod +x "$APP_EXEC"
touch "$APP_BUNDLE"

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
        <string>$APP_EXEC</string>
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
ラッパー .app   : $APP_BUNDLE
保存先          : $MOVIES_DIR/<ソース>/<年>/<日付>/<機種>/
ログ            : $LOG_DIR/import-media.log
自動アップデート : 毎日 04:00 に git pull
==========================================

次の手順（これをやらないと動きません）:
  1. Finder で ~/Applications を開く（Cmd+Shift+G で ~/Applications）
  2. システム設定 → プライバシーとセキュリティ → フルディスクアクセス
  3. Finder の MediaImport アプリを、FDA リストに **ドラッグ＆ドロップ**
  4. 追加された MediaImport のトグルを ON にする
  5. SDカードを差すか AirDrop で動画を受信 → 自動取り込み開始

EOF

if [[ -t 0 ]]; then
  read -r -p "今すぐシステム設定を開きますか？ (y/N) " yn
  if [[ "$yn" =~ ^[Yy] ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  fi
fi
