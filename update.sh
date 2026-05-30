#!/bin/bash
# Daily auto-updater. Pulls latest from origin and re-runs install.sh if anything changed.
set -e
INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG="$HOME/Library/Logs/import-media-update.log"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
  log "Not a git checkout — skipping auto-update."
  exit 0
fi

cd "$INSTALL_DIR"
before=$(/usr/bin/git rev-parse HEAD 2>/dev/null || echo "")
if ! /usr/bin/git pull --quiet --rebase 2>>"$LOG"; then
  log "git pull failed."
  exit 0
fi
after=$(/usr/bin/git rev-parse HEAD 2>/dev/null || echo "")

if [[ -n "$after" && "$before" != "$after" ]]; then
  log "Updated $before -> $after"
  /bin/bash "$INSTALL_DIR/install.sh" --quiet 2>>"$LOG" || log "install.sh failed"
  /usr/bin/osascript -e 'display notification "取り込みシステムを更新しました" with title "Media Import" sound name "Glass"' >/dev/null 2>&1 || true
else
  log "Already up to date."
fi
