#!/bin/bash
# Drain the deferred-notification queue written by import-media.sh.
#
# For each pending session, check whether all of its files have finished
# uploading to the Drive cloud (a file gains the com.google.drivefs.item-id
# xattr once Google Drive has it). When every file is uploaded, send the LINE
# notification — so the team is pinged only when the videos are actually
# available/playable in Drive, not merely copied to the local mount.
#
# Run every ~2 minutes by the com.user.importmedia.notify LaunchAgent.
set -uo pipefail

PENDING_DIR="$HOME/Library/Caches/import-media-pending"
NOTIFY="$HOME/bin/notify-line.sh"
LOG="$HOME/Library/Logs/import-media.log"
MAX_WAIT=$(( 6 * 3600 ))   # after 6h, send anyway rather than never

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

[[ -d "$PENDING_DIR" ]] || exit 0
[[ -x "$NOTIFY" ]]      || exit 0

uploaded() {
  # Uploaded == has a Drive item-id xattr. Missing file → treat as done
  # (it was moved/deleted, nothing to wait for).
  [[ -e "$1" ]] || return 0
  [[ -n "$(/usr/bin/xattr -p 'com.google.drivefs.item-id#S' "$1" 2>/dev/null)" ]]
}

shopt -s nullglob
for pend in "$PENDING_DIR"/*.pending; do
  enqueued=0 total=0 pending=0
  while IFS= read -r line; do
    case "$line" in
      "@enqueued "*) enqueued="${line#@enqueued }" ;;
      "@dst "*)
        dst="${line#@dst }"
        total=$((total + 1))
        uploaded "$dst" || pending=$((pending + 1))
        ;;
      "@message") break ;;
    esac
  done < "$pend"

  now=$(date +%s)
  aged=$(( now - enqueued ))

  if [[ $pending -eq 0 ]]; then
    msg=$(/usr/bin/awk 'f{print} /^@message$/{f=1}' "$pend")
    "$NOTIFY" "$msg" >> "$LOG" 2>&1 || log "notify-uploads: send failed for $(basename "$pend")"
    log "notify-uploads: upload complete ($total files) → notified: $(basename "$pend")"
    /bin/rm -f "$pend"
  elif [[ $aged -ge $MAX_WAIT ]]; then
    msg=$(/usr/bin/awk 'f{print} /^@message$/{f=1}' "$pend")
    "$NOTIFY" "$msg

⚠️ 一部ファイルがまだアップロード中の可能性があります（未完了 ${pending}/${total} 件）" >> "$LOG" 2>&1 || true
    log "notify-uploads: timed out after ${aged}s, notified anyway (${pending}/${total} pending): $(basename "$pend")"
    /bin/rm -f "$pend"
  else
    log "notify-uploads: waiting on upload (${pending}/${total} pending): $(basename "$pend")"
  fi
done
