#!/bin/bash
# import-media.sh
# Auto-imports videos from:
#   - SD cards mounted under /Volumes (GoPro, DJI / Osmo)
#   - ~/Downloads (AirDrop from iPhone, GigaFile-bin, etc.)
# Destination: ~/Movies/<SOURCE>/YYYY/YYYY-MM-DD/
#   based on the ORIGINAL recording date in the file metadata or filename.
set -uo pipefail

DEST_BASE="$HOME/Movies"
DOWNLOADS="$HOME/Downloads"
LOG="$HOME/Library/Logs/import-media.log"
LOCK_FILE="$HOME/Library/Caches/import-media.pid"
mkdir -p "$DEST_BASE" "$(dirname "$LOG")" "$(dirname "$LOCK_FILE")"

# ==== Configuration ====
# Delete file from the SD card after a successfully verified copy.
DELETE_FROM_CARD="false"         # "true" or "false"
# How to verify the copy before deleting source:
#   size  — file sizes match (rsync also runs its own rolling checksum during transfer). Fast.
#   hash  — full SHA-256 compare on both sides. Bulletproof but slow (~2-3 min per 17GB file).
#   none  — trust rsync's exit code only. Fastest, least paranoid.
VERIFY_MODE="size"
# =======================

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }

# PID-based single-instance lock with stale recovery.
# If a previous run was killed before cleanup, we detect the dead PID and take over.
if [[ -f "$LOCK_FILE" ]]; then
  old_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
  log "Stale lock (pid=$old_pid) — taking over"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

notify() {
  /usr/bin/osascript -e "display notification \"$2\" with title \"Media Import\" subtitle \"$1\" sound name \"Tink\"" >/dev/null 2>&1 || true
}

notify_done() {
  # Louder completion notification.
  /usr/bin/osascript -e "display notification \"$2\" with title \"✅ 取り込み完了\" subtitle \"$1\" sound name \"Glass\"" >/dev/null 2>&1 || true
  /usr/bin/afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
}

open_in_finder() {
  /usr/bin/open "$1" >/dev/null 2>&1 || true
}

# Verify a destination file is a faithful copy of the source.
# Returns 0 (success) only when the configured check passes.
verify_copy() {
  local src="$1" dst="$2"
  [[ -e "$src" && -e "$dst" ]] || return 1
  case "$VERIFY_MODE" in
    none)
      return 0
      ;;
    hash)
      local sh dh
      sh=$(/usr/bin/shasum -a 256 "$src" 2>/dev/null | /usr/bin/cut -d' ' -f1)
      dh=$(/usr/bin/shasum -a 256 "$dst" 2>/dev/null | /usr/bin/cut -d' ' -f1)
      [[ -n "$sh" && "$sh" == "$dh" ]]
      ;;
    *)  # size (default)
      local ss ds
      ss=$(/usr/bin/stat -f %z "$src" 2>/dev/null || echo "")
      ds=$(/usr/bin/stat -f %z "$dst" 2>/dev/null || echo "")
      [[ -n "$ss" && "$ss" == "$ds" && "$ss" -gt 0 ]]
      ;;
  esac
}

# ---------- Date extraction (original recording date) ----------
# Priority:
#   1. Spotlight content-creation metadata (most reliable when indexed)
#   2. Filename pattern: DJI_YYYYMMDD... / IMG_YYYYMMDD...
#   3. File mtime (skip if 1970 — SD cards often have broken mtimes)
#   4. Today (last resort, so the file is at least placed)
get_creation_date() {
  local f="$1" d="" name
  name=$(basename "$f")

  d=$(/usr/bin/mdls -raw -name kMDItemContentCreationDate "$f" 2>/dev/null || true)
  if [[ -n "$d" && "$d" != "(null)" && "${d:0:4}" != "1970" ]]; then
    printf '%s' "${d:0:10}"; return
  fi
  if [[ "$name" =~ ^DJI_([0-9]{4})([0-9]{2})([0-9]{2})[0-9] ]]; then
    printf '%s-%s-%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"; return
  fi
  if [[ "$name" =~ ^IMG_([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
    printf '%s-%s-%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"; return
  fi
  d=$(/usr/bin/stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null || echo "")
  if [[ -n "$d" && "${d:0:4}" != "1970" ]]; then
    printf '%s' "$d"; return
  fi
  /bin/date +%Y-%m-%d
}

# ---------- Step 1: Device identification (raw) ----------
# Returns the raw model identifier (e.g. "DJI Osmo Pocket 4", "HERO12 Black").
# Falls back to filename heuristics, then empty.
detect_device_raw() {
  local f="$1" source="$2" model=""
  model=$(/usr/bin/mdls -raw -name kMDItemAcquisitionModel "$f" 2>/dev/null)
  if [[ -z "$model" || "$model" == "(null)" ]]; then
    /usr/bin/mdimport "$f" >/dev/null 2>&1
    model=$(/usr/bin/mdls -raw -name kMDItemAcquisitionModel "$f" 2>/dev/null)
  fi
  if [[ -n "$model" && "$model" != "(null)" ]]; then
    printf '%s' "$model"
    return
  fi
  case "$source/$(basename "$f")" in
    DJI/*_D.MP4|DJI/*_D.mp4) printf 'DJI Osmo Pocket'; return ;;
    DJI/*_S.MP4|DJI/*_S.mp4) printf 'DJI Osmo Action'; return ;;
  esac
  printf ''
}

# ---------- Step 2: Folder-name mapping ----------
# Decide which folder each device's files land in.
# Edit this table to rename folders or merge/split devices however you like.
# Format: "$SOURCE|$RAW_MODEL_NAME"  →  echo "FolderName"
device_folder_name() {
  local source="$1" raw="$2"
  case "$source|$raw" in
    "DJI|DJI Osmo Pocket 4")        echo "Pocket4";   return ;;
    "DJI|DJI Osmo Pocket 3")        echo "Pocket3";   return ;;
    "DJI|DJI Osmo Pocket")          echo "Pocket";    return ;;
    "DJI|DJI Osmo Action 5 Pro")    echo "Action5";   return ;;
    "DJI|DJI Osmo Action 4")        echo "Action4";   return ;;
    "DJI|DJI Osmo Action")          echo "Action";    return ;;
    "DJI|DJI Mavic 3 Pro")          echo "Mavic3";    return ;;
    "DJI|DJI Mavic 3")              echo "Mavic3";    return ;;
    "DJI|DJI Mini 4 Pro")           echo "Mini4";     return ;;
    "DJI|DJI Mini 4")               echo "Mini4";     return ;;
    "GoPro|HERO13 Black")           echo "HERO13";    return ;;
    "GoPro|HERO12 Black")           echo "HERO12";    return ;;
    "GoPro|HERO11 Black")           echo "HERO11";    return ;;
    # Unmapped devices fall through to the default below.
  esac
  # Default: strip common brand prefix, use as-is.
  local n="$raw"
  n="${n#DJI Osmo }"; n="${n#DJI }"; n="${n#GoPro }"; n="${n#Apple }"
  [[ -n "$n" ]] && echo "$n" || echo "Unknown"
}

# ---------- Source detection for a single file (used for Downloads) ----------
detect_source_from_file() {
  local f="$1" make=""
  make=$(/usr/bin/mdls -raw -name kMDItemAcquisitionMake "$f" 2>/dev/null || true)
  case "$make" in
    *GoPro*|*GOPRO*) echo "GoPro";  return ;;
    *Apple*)         echo "iPhone"; return ;;
    *DJI*|*dji*)     echo "DJI";    return ;;
  esac
  case "$(basename "$f")" in
    GX*|GH*|GOPR*)                            echo "GoPro";  return ;;
    DJI_*)                                    echo "DJI";    return ;;
    IMG_*.MOV|IMG_*.mov|IMG_*.MP4|IMG_*.mp4)  echo "iPhone"; return ;;
  esac
  echo "Other"
}

# ---------- Place a file into <SOURCE>/YYYY/YYYY-MM-DD/ ----------
# Args: source-file, source-label, mode (copy|move)
# Returns 0 if newly placed, 1 if skipped/duplicate.
place_file() {
  local f="$1" source="$2" mode="$3"
  local date_str year raw device dest_dir dest
  date_str=$(get_creation_date "$f")
  year="${date_str:0:4}"
  if [[ "$source" == "Other" ]]; then
    dest_dir="$DEST_BASE/$source/$year/$date_str"
  else
    raw=$(detect_device_raw "$f" "$source")
    device=$(device_folder_name "$source" "$raw")
    dest_dir="$DEST_BASE/$source/$year/$date_str/$device"
  fi
  dest="$dest_dir/$(basename "$f")"
  mkdir -p "$dest_dir"

  # Already imported — handle source cleanup if requested.
  if [[ -e "$dest" ]] && \
     [[ "$(/usr/bin/stat -f %z "$f")" == "$(/usr/bin/stat -f %z "$dest")" ]]; then
    if [[ "$mode" == "move" ]]; then
      /bin/rm -f "$f"
      log "  = [$source] dup removed from source: $(basename "$f")"
    elif [[ "$mode" == "copy" && "$DELETE_FROM_CARD" == "true" ]]; then
      if verify_copy "$f" "$dest"; then
        /bin/rm -f "$f"
        log "  = [$source] already imported, removed from card: $(basename "$f")"
      else
        log "  ! [$source] dup but verify failed, KEEPING source: $(basename "$f")"
      fi
    fi
    return 1
  fi

  if [[ "$mode" == "move" ]]; then
    if /bin/mv -n "$f" "$dest" 2>/dev/null && [[ -e "$dest" ]]; then
      log "  + [$source] $dest (moved)"
      return 0
    fi
  fi
  if /usr/bin/rsync -t --partial "$f" "$dest"; then
    log "  + [$source] $dest"
    # Copy mode + delete-from-card: verify, then remove the source.
    if [[ "$mode" == "copy" && "$DELETE_FROM_CARD" == "true" ]]; then
      if verify_copy "$f" "$dest"; then
        /bin/rm -f "$f"
        log "  x [$source] source removed from card: $(basename "$f")"
      else
        log "  ! [$source] VERIFY FAILED — source kept on card: $(basename "$f")"
      fi
    fi
    return 0
  fi
  log "  ! failed: $f"
  return 1
}

# ---------- SD card handling ----------
detect_volume_source() {
  local vol="$1"
  if [[ -f "$vol/MISC/version.txt" ]] || \
     ls -d "$vol/DCIM"/*GOPRO 2>/dev/null | grep -q .; then
    echo "GoPro"; return
  fi
  if [[ -d "$vol/MISC/DJI" ]] || \
     /usr/bin/find "$vol/DCIM" -maxdepth 4 -name 'DJI_*' -print -quit 2>/dev/null | grep -q .; then
    echo "DJI"; return
  fi
  echo ""
}

# Lists all importable media files on a volume.
# Uses DCIM/ if present (full depth), else scans the volume root up to maxdepth 6.
find_volume_media() {
  local vol="$1"
  shift
  local root="$vol" maxdepth_arg=()
  if [[ -d "$vol/DCIM" ]]; then
    root="$vol/DCIM"
  else
    maxdepth_arg=(-maxdepth 6)
  fi
  /usr/bin/find "$root" "${maxdepth_arg[@]}" -type f \
    ! -name '._*' ! -name '.DS_Store' \( \
      -iname '*.MP4' -o -iname '*.MOV' -o -iname '*.M4V' -o -iname '*.LRV' \
      -o -iname '*.THM' -o -iname '*.JPG' -o -iname '*.WAV' \
      -o -iname '*.INSV' -o -iname '*.DNG' -o -iname '*.RAW' \
      -o -iname '*.AVI' -o -iname '*.MKV' -o -iname '*.MTS' \
      -o -iname '*.M2TS' -o -iname '*.WMV' -o -iname '*.HEIC' \
    \) "$@" 2>/dev/null
}

import_volume() {
  local vol="$1"
  local source_hint
  source_hint=$(detect_volume_source "$vol")   # may be empty

  # Pre-count. Skip volumes with no media at all so plugging in a USB drive doesn't fire empty notifications.
  local total
  total=$(find_volume_media "$vol" | wc -l | tr -d ' ')
  [[ $total -eq 0 ]] && return

  local label="${source_hint:-SDカード}"
  log "==> Volume $vol (hint: ${source_hint:-generic}), $total files"
  notify "🟢 $label $(basename "$vol")" "$total 件を確認中..."

  # Open the destination folder right away so the user can see files arriving in real time.
  # For a known source (GoPro/DJI/etc.) open that source root; otherwise open ~/Movies.
  if [[ -n "$source_hint" ]]; then
    open_in_finder "$DEST_BASE/$source_hint"
  else
    open_in_finder "$DEST_BASE"
  fi

  local copied=0 scanned=0 last_source=""
  while IFS= read -r -d '' f; do
    scanned=$((scanned + 1))
    # Use the volume hint if known, else detect per-file from MP4 metadata / filename.
    local source
    if [[ -n "$source_hint" ]]; then
      source="$source_hint"
    else
      source=$(detect_source_from_file "$f")
    fi
    if place_file "$f" "$source" "copy"; then
      copied=$((copied + 1))
      last_source="$source"
    fi
  done < <(find_volume_media "$vol" -print0)
  log "<== Volume done: $copied new / $scanned scanned ($vol)"

  if [[ $copied -gt 0 ]]; then
    notify_done "$label ($(basename "$vol"))" "新規 $copied 件 / 既存 $((scanned - copied)) 件"
    open_in_finder "$DEST_BASE/${source_hint:-$last_source}"
  else
    notify "$label $(basename "$vol")" "新規なし (既存 $scanned 件すべてスキップ)"
  fi
}

scan_volumes() {
  for vol in /Volumes/*/; do
    vol="${vol%/}"
    # Skip macOS system volumes — never scan the boot drive.
    case "$(basename "$vol")" in
      "Macintosh HD"|"Macintosh HD - Data"|"Recovery"|"Preboot"|"VM"|"Update"|"xarts"|"iSCPreboot")
        continue ;;
    esac
    [[ -d "$vol/System" ]] && continue   # boot-volume firmlink safety net
    import_volume "$vol"
  done
}

# ---------- Downloads handling ----------
is_settled() {
  local f="$1" s1 s2
  s1=$(/usr/bin/stat -f %z "$f" 2>/dev/null || echo "")
  sleep 2
  s2=$(/usr/bin/stat -f %z "$f" 2>/dev/null || echo "")
  [[ -n "$s1" && "$s1" == "$s2" ]]
}

scan_downloads() {
  [[ -d "$DOWNLOADS" ]] || return
  local placed=0 last_dest=""
  while IFS= read -r -d '' f; do
    case "$f" in
      *.crdownload|*.download|*.part) continue ;;
    esac
    [[ "$(basename "$f")" == ._* ]] && continue
    is_settled "$f" || { log "skip (still writing): $f"; continue; }
    local source
    source=$(detect_source_from_file "$f")
    if place_file "$f" "$source" "move"; then
      placed=$((placed + 1))
      last_dest="$DEST_BASE/$source"
    fi
  done < <(/usr/bin/find "$DOWNLOADS" -maxdepth 2 -type f ! -name '._*' \( \
        -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' \
        -o -iname '*.insv' -o -iname '*.lrv' \
      \) -print0 2>/dev/null)
  if [[ $placed -gt 0 ]]; then
    log "<== Downloads done: $placed moved"
    notify_done "Downloads → Movies" "$placed 件を移動"
    [[ -n "$last_dest" ]] && open_in_finder "$last_dest"
  fi
}

# ---------- Main ----------
sleep 2
scan_volumes
scan_downloads
