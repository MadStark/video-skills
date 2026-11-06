#!/bin/bash
# vp.sh - Antoine's video project helper (macOS, bash 3.2 compatible)
#
#   vp.sh create "<title>" [number]
#   vp.sh import --project <p> [--source DIR] [--label GOPRO] [--into FOLDER] [--dry-run] [--delete-lrf] [--checksum]
#   vp.sh relink <project|all> [--check]
#   vp.sh status
#   vp.sh projects            (one project folder per line, newest number first)
#
# Env overrides: VP_EDITS (default /Volumes/Recordings/Edits), VP_TEMPLATE (default "ZZZ - Template 2.0"),
#                VP_FORCE=1 to skip the "Final Cut Pro is running" guard.
set -euo pipefail

EDITS="${VP_EDITS:-/Volumes/Recordings/Edits}"
TEMPLATE="${VP_TEMPLATE:-ZZZ - Template 2.0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BM="$HERE/bookmark.js"
LOCATION_KEYS="backupLocation mediaLocation cacheLocation"

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "• $*"; }

fcp_running() { pgrep -x "Final Cut Pro" >/dev/null 2>&1; }
guard_fcp() {
  if fcp_running && [ -z "${VP_FORCE:-}" ]; then
    die "Final Cut Pro is running. Quit it first so the libraries are not open/locked."
  fi
}
fsize() { stat -f%z "$1"; }
human() { awk -v b="$1" 'BEGIN{s="B KB MB GB TB";split(s,u," ");i=1;while(b>=1024&&i<5){b/=1024;i++}printf "%.1f %s",b,u[i]}'; }
is_empty_dir() { [ -z "$(find "$1" -type f ! -name '._*' ! -name '.DS_Store' 2>/dev/null | head -1)" ]; }

next_number() {
  local n
  n=$(ls "$EDITS" | sed -n 's/^\([0-9][0-9]*\) - .*/\1/p' | sort -n | tail -1)
  echo $(( ${n:-0} + 1 ))
}

list_projects() {
  ls "$EDITS" | grep -E '^[0-9]+ - ' | sort -rn | while IFS= read -r d; do echo "$EDITS/$d"; done
}

resolve_project() {
  local q="$1" m n
  [ -n "$q" ] || die "no project given"
  if [ -d "$q" ]; then (cd "$q" && pwd); return; fi
  if [ -d "$EDITS/$q" ]; then echo "$EDITS/$q"; return; fi
  if echo "$q" | grep -qE '^[0-9]+$'; then
    m=$(ls -d "$EDITS/$q - "* 2>/dev/null || true)
  else
    m=$(list_projects | grep -i -F -- "$q" || true)
  fi
  n=$(printf '%s\n' "$m" | grep -c . || true)
  [ "$n" = "1" ] || die "project '$q' matched $n folders:${m:+
$m}"
  echo "$m"
}

libraries() { ls -d "$1"/01_LIBRARY/*.fcpbundle 2>/dev/null || true; }

# ---- bookmarks -------------------------------------------------------------
bm_path() { # plist key -> path stored in bookmark (fails if key missing)
  local b64
  b64=$(plutil -extract "$2" raw -o - "$1" 2>/dev/null) || return 1
  osascript -l JavaScript "$BM" path "$b64"
}
bm_set() { # plist key folder
  local b64
  mkdir -p "$3"
  b64=$(osascript -l JavaScript "$BM" make "$3")
  plutil -replace "$2" -data "$b64" "$1"
}
plist_str() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

# relink_bundle <bundle> <project root> <fix|check>
# Any location stored under $EDITS/<other folder>/rest is re-pointed to <project root>/rest.
# In check mode prints status and returns the number of bad keys.
relink_bundle() {
  local bundle="$1" root="$2" mode="$3" plist="$1/Settings.plist" key p rel first newp bad=0 libname
  [ -f "$plist" ] || { echo "  (no Settings.plist in $bundle)"; return 0; }
  libname=$(plist_str "$plist" backupFolderName || basename "$bundle" .fcpbundle)
  echo "  library: $(basename "$bundle")"
  for key in $LOCATION_KEYS; do
    if ! p=$(bm_path "$plist" "$key"); then echo "    -    $key: default (inside library)"; continue; fi
    case "$p" in "$root"|"$root"/*) echo "    ok   $key -> ${p#"$EDITS"/}"; continue;; esac
    case "$p" in
      "$EDITS"/*)
        first="${p#"$EDITS"/}"; rel="${first#*/}"; [ "$rel" = "$first" ] && rel=""
        newp="$root${rel:+/$rel}";;
      *) echo "    WARN $key -> $p (outside $EDITS, left alone)"; continue;;
    esac
    if [ "$mode" = "check" ]; then
      echo "    BAD  $key -> ${p#"$EDITS"/}   (should be ${newp#"$EDITS"/})"; bad=$((bad+1))
    else
      bm_set "$plist" "$key" "$newp"
      echo "    fixed $key: ${p#"$EDITS"/} -> ${newp#"$EDITS"/}"
      if [ "$key" = "backupLocation" ] && [ -d "$p/$libname" ] && [ ! -e "$newp/$libname" ]; then
        mv "$p/$libname" "$newp/$libname"
        echo "    moved existing backups $libname -> ${newp#"$EDITS"/}/"
      fi
    fi
  done
  return $bad
}

# ---- create ----------------------------------------------------------------
cmd_create() {
  local title="${1:-}" n="${2:-}" tpl dest src new
  [ -n "$title" ] || die 'usage: vp.sh create "<title>" [number]'
  case "$title" in */*|*:*) die "title can't contain / or :";; esac
  [ -d "$EDITS" ] || die "$EDITS is not mounted"
  tpl="$EDITS/$TEMPLATE"; [ -d "$tpl" ] || die "template not found: $tpl"
  guard_fcp
  [ -n "$n" ] || n=$(next_number)
  dest="$EDITS/$n - $title"
  [ -e "$dest" ] && die "already exists: $dest"

  info "Copying '$TEMPLATE' -> '$n - $title'"
  ditto "$tpl" "$dest"
  find "$dest/01_LIBRARY" -maxdepth 2 -name '*.lock*' -exec rm -rf {} + 2>/dev/null || true
  [ -d "$dest/99_BACKUPS" ] && find "$dest/99_BACKUPS" -mindepth 1 -delete

  src=$(libraries "$dest" | head -1)
  [ -n "$src" ] || die "no .fcpbundle found in template 01_LIBRARY"
  new="$dest/01_LIBRARY/$title.fcpbundle"
  if [ "$src" != "$new" ]; then
    mv "$src" "$new"
    [ -e "$dest/01_LIBRARY/._$(basename "$src")" ] && mv "$dest/01_LIBRARY/._$(basename "$src")" "$dest/01_LIBRARY/._$title.fcpbundle"
  fi
  info "Library renamed to '$title.fcpbundle'"
  plist_str "$new/Settings.plist" backupFolderName >/dev/null && plutil -replace backupFolderName -string "$title" "$new/Settings.plist"
  plist_str "$new/Settings.plist" cacheFolderName  >/dev/null && plutil -replace cacheFolderName -string "$title Cache.fcpcache" "$new/Settings.plist"

  info "Re-pointing library locations to the new project"
  relink_bundle "$new" "$dest" fix
  info "Verification"
  relink_bundle "$new" "$dest" check || die "some locations still point outside the project"
  echo "PROJECT=$dest"
  echo "LIBRARY=$new"
}

# ---- import ----------------------------------------------------------------
SLOT_ACTION=""; SLOT_FROM=""; SLOT_TO=""
pick_slot() { # cams label
  local cams="$1" label="$2" L existing cnt base
  for L in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
    existing=$(ls -d "$cams/${L}_"* 2>/dev/null | grep -v '/\._' || true)
    if [ -z "$existing" ]; then SLOT_ACTION=create; SLOT_TO="$cams/${L}_$label"; return; fi
    cnt=$(printf '%s\n' "$existing" | grep -c .)
    [ "$cnt" = "1" ] || continue
    base=$(basename "$existing")
    if [ "$base" = "${L}_CAM" ] || [ "$base" = "${L}_$label" ]; then
      if is_empty_dir "$existing"; then
        if [ "$base" = "${L}_$label" ]; then SLOT_ACTION=use; else SLOT_ACTION=rename; fi
        SLOT_FROM="$existing"; SLOT_TO="$cams/${L}_$label"; return
      fi
    fi
  done
  die "no free camera slot (A-Z) in $cams"
}

cmd_import() {
  local proj="" src="/Volumes/DJI/DCIM" label="GOPRO" into="" dry=0 del_lrf=0 checksum=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --project) proj="$2"; shift 2;;
      --source)  src="$2"; shift 2;;
      --label)   label="$2"; shift 2;;
      --into)    into="$2"; shift 2;;
      --dry-run) dry=1; shift;;
      --delete-lrf) del_lrf=1; shift;;
      --checksum) checksum=1; shift;;
      *) die "unknown option $1";;
    esac
  done
  proj=$(resolve_project "$proj")
  [ -d "$src" ] || die "source not found: $src (is the card mounted?)"
  label=$(echo "$label" | tr '[:lower:] ' '[:upper:]_')
  local cams="$proj/02_MEDIA/01_CAMERAS"
  [ -d "$cams" ] || cams="$proj/02_MEDIA/01_CAMERA"
  [ -d "$cams" ] || die "no 02_MEDIA/01_CAMERAS folder in $proj"

  if [ -n "$into" ]; then SLOT_TO="$cams/$into"; SLOT_ACTION=use; [ -d "$SLOT_TO" ] || SLOT_ACTION=create
  else pick_slot "$cams" "$label"; fi

  local mp4s lrfs nm nl total=0 f
  mp4s=$(find "$src" -type f -iname '*.mp4' ! -name '._*' | sort)
  lrfs=$(find "$src" -type f -iname '*.lrf' ! -name '._*' | sort)
  nm=$(printf '%s\n' "$mp4s" | grep -c . || true)
  nl=$(printf '%s\n' "$lrfs" | grep -c . || true)
  [ "$nm" -gt 0 ] || die "no MP4 files found in $src"
  if [ -n "$mp4s" ]; then while IFS= read -r f; do total=$((total + $(fsize "$f"))); done <<< "$mp4s"; fi
  local free=$(( $(df -k "$cams" | awk 'NR==2{print $4}') * 1024 ))

  echo "PROJECT:     ${proj#"$EDITS"/}"
  echo "SOURCE:      $src"
  case "$SLOT_ACTION" in
    rename) echo "DESTINATION: rename $(basename "$SLOT_FROM") -> $(basename "$SLOT_TO")";;
    create) echo "DESTINATION: create $(basename "$SLOT_TO")";;
    use)    echo "DESTINATION: use existing $(basename "$SLOT_TO")";;
  esac
  echo "MP4:         $nm files, $(human $total) (moved, then deleted from card)"
  echo "LRF:         $nl files ($( [ $del_lrf = 1 ] && echo 'will be PERMANENTLY deleted' || echo 'kept; pass --delete-lrf to delete'))"
  echo "FREE SPACE:  $(human $free) on destination"
  [ "$total" -lt "$free" ] || die "not enough free space on destination"
  [ $dry = 1 ] && { echo "(dry run, nothing changed)"; return 0; }

  guard_fcp
  case "$SLOT_ACTION" in
    rename) mv "$SLOT_FROM" "$SLOT_TO";;
    create) mkdir -p "$SLOT_TO";;
  esac
  local dest="$SLOT_TO" base d moved=0 skipped=0 i=0 s1 s2
  if [ -n "$mp4s" ]; then
    while IFS= read -r f; do
      i=$((i+1)); base=$(basename "$f"); d="$dest/$base"
      s1=$(fsize "$f")
      if [ -e "$d" ]; then
        if [ "$(fsize "$d")" = "$s1" ]; then
          echo "[$i/$nm] $base already at destination (same size), removing from card"
          rm -f "$f" "$(dirname "$f")/._$base"; moved=$((moved+1)); continue
        fi
        echo "[$i/$nm] SKIP $base: a different file with that name exists at destination"; skipped=$((skipped+1)); continue
      fi
      echo "[$i/$nm] $base ($(human $s1))"
      cp "$f" "$d.partial"
      touch -r "$f" "$d.partial" 2>/dev/null || true
      s2=$(fsize "$d.partial")
      if [ "$s1" != "$s2" ]; then echo "    SIZE MISMATCH, keeping card copy"; rm -f "$d.partial"; skipped=$((skipped+1)); continue; fi
      if [ $checksum = 1 ] && [ "$(shasum -a 256 < "$f")" != "$(shasum -a 256 < "$d.partial")" ]; then
        echo "    CHECKSUM MISMATCH, keeping card copy"; rm -f "$d.partial"; skipped=$((skipped+1)); continue
      fi
      mv "$d.partial" "$d"
      rm -f "$f" "$(dirname "$f")/._$base"
      moved=$((moved+1))
    done <<< "$mp4s"
  fi
  local deleted=0
  if [ $del_lrf = 1 ] && [ -n "$lrfs" ]; then
    while IFS= read -r f; do rm -f "$f" "$(dirname "$f")/._$(basename "$f")"; deleted=$((deleted+1)); done <<< "$lrfs"
  fi
  echo "DONE: $moved MP4 moved to ${dest#"$EDITS"/}, $skipped skipped, $deleted LRF deleted"
  [ $skipped = 0 ] || exit 2
}

# ---- relink / status -------------------------------------------------------
cmd_relink() {
  local target="${1:-}" mode=fix p b bad=0
  [ "${2:-}" = "--check" ] && mode=check
  [ -n "$target" ] || die "usage: vp.sh relink <project|all> [--check]"
  [ $mode = fix ] && guard_fcp
  { if [ "$target" = all ]; then list_projects; else resolve_project "$target"; fi; } | while IFS= read -r p; do
    echo "${p#"$EDITS"/}"
    libraries "$p" | while IFS= read -r b; do
      [ -n "$b" ] && { relink_bundle "$b" "$p" "$mode" || true; }
    done
  done
}

cmd_status() {
  local p name size clips libs b state
  printf '%-45s %8s %6s  %s\n' PROJECT SIZE CLIPS LIBRARY_PATHS
  list_projects | while IFS= read -r p; do
    name="${p#"$EDITS"/}"
    size=$(du -sh "$p" 2>/dev/null | cut -f1)
    clips=$(find "$p/02_MEDIA" -type f \( -iname '*.mp4' -o -iname '*.mov' \) ! -name '._*' 2>/dev/null | wc -l | tr -d ' ')
    state=ok
    libs=$(libraries "$p")
    if [ -z "$libs" ]; then state="no library"
    else
      while IFS= read -r b; do
        relink_bundle "$b" "$p" check >/dev/null 2>&1 || state="BAD (run relink)"
      done <<< "$libs"
    fi
    printf '%-45s %8s %6s  %s\n' "$name" "$size" "$clips" "$state"
  done
}

case "${1:-}" in
  create)   shift; cmd_create "$@";;
  import)   shift; cmd_import "$@";;
  relink)   shift; cmd_relink "$@";;
  status)   cmd_status;;
  projects) list_projects;;
  next)     next_number;;
  *) sed -n '2,11p' "$0"; exit 1;;
esac
