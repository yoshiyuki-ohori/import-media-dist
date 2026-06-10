#!/bin/bash
# Drain the deferred-notification queue written by import-media.sh.
#
# For each pending session, check whether all of its files have finished
# uploading to the Drive cloud (a file gains the com.google.drivefs.item-id
# xattr once Google Drive has it). When every file is uploaded, send the LINE
# notification — so the team is pinged only when the videos are actually
# available/playable in Drive, not merely copied to the local mount.
#
# If a session is still uploading after SLOW_AFTER (1h), send a one-time
# "still uploading" heads-up but keep waiting for real completion. As a last
# resort, give up after GIVEUP_AFTER (24h) with a failure notice so a stuck
# upload neither swallows the notification nor lingers forever.
#
# Run every ~2 minutes by the com.user.importmedia.notify LaunchAgent.
set -uo pipefail

PENDING_DIR="$HOME/Library/Caches/import-media-pending"
NOTIFY="$HOME/bin/notify-line.sh"
LOG="$HOME/Library/Logs/import-media.log"
SLOW_AFTER=$(( 1 * 3600 ))    # 1h still uploading → one-time heads-up
GIVEUP_AFTER=$(( 24 * 3600 )) # 24h → give up, notify failure, stop waiting

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
send() { "$NOTIFY" "$1" >> "$LOG" 2>&1 || log "notify-uploads: send failed"; }

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

  msg=$(/usr/bin/awk 'f{print} /^@message$/{f=1}' "$pend")
  now=$(date +%s)
  aged=$(( now - enqueued ))

  if [[ $pending -eq 0 ]]; then
    # All files are in the cloud → send the real completion notice.
    send "$msg"
    log "notify-uploads: upload complete ($total files) → notified: $(basename "$pend")"
    /bin/rm -f "$pend"
  elif [[ $aged -ge $GIVEUP_AFTER ]]; then
    # Stuck for a full day → stop waiting, report failure.
    send "$msg

⚠️ アップロードが完了しませんでした（未完了 ${pending}/${total} 件）。Drive の同期状態を確認してください。"
    log "notify-uploads: gave up after ${aged}s (${pending}/${total} pending): $(basename "$pend")"
    /bin/rm -f "$pend"
  elif [[ $aged -ge $SLOW_AFTER ]] && ! /usr/bin/grep -q '^@slow_notified' "$pend"; then
    # Taking a while → one-time heads-up, then keep waiting for completion.
    send "⏳ アップロードに時間がかかっています（残り ${pending}/${total} 件）。完了したら改めてお知らせします。"
    printf '@slow_notified %s\n' "$now" >> "$pend"
    log "notify-uploads: slow heads-up sent (${pending}/${total} pending): $(basename "$pend")"
  else
    log "notify-uploads: waiting on upload (${pending}/${total} pending): $(basename "$pend")"
  fi
done
