#!/system/bin/sh
# Explicit, opt-in MTS-only helper for Realme GT Neo 5 SE (RMX3701).
# This script is NOT installed as a KernelSU service and never runs automatically.
# It changes /data/vendor/radio/iccid_0. Use only with a verified local ICCID and backup.
set -eu
umask 077

TARGET=/data/vendor/radio/iccid_0
BACKUP_DIR=/data/local/tmp/rmx3701-ims-backup
EXPECTED_ICCID=${RMX3701_MTS_ICCID:-}
EXPECTED_CONTEXT=u:object_r:vendor_radio_vendor_data_file:s0
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

MODEL=$(getprop ro.product.device)
VENDOR_MODEL=$(getprop ro.product.vendor.device)
FINGERPRINT=$(getprop ro.build.fingerprint)
case "$MODEL $VENDOR_MODEL $FINGERPRINT" in
  *RMX3701*|*RE58D1L1*) ;;
  *) echo "ERROR: target identity is not confirmed as RMX3701." >&2; exit 2 ;;
esac

if [ "$FORCE" -ne 1 ]; then
  echo "ERROR: explicit --force is required; no change made." >&2
  echo "Usage: RMX3701_MTS_ICCID=<19-or-20-digit-ICCID> sh $0 --force" >&2
  exit 2
fi
if [ -z "$EXPECTED_ICCID" ]; then
  echo "ERROR: set RMX3701_MTS_ICCID locally; never commit the real value." >&2
  exit 2
fi
case "$EXPECTED_ICCID" in
  *[!0-9]*) echo "ERROR: ICCID must contain decimal digits only." >&2; exit 2 ;;
esac
ICCID_LENGTH=$(printf '%s' "$EXPECTED_ICCID" | wc -c | tr -d ' ')
case "$ICCID_LENGTH" in
  19|20) ;;
  *) echo "ERROR: ICCID length must be 19 or 20 digits; no change made." >&2; exit 2 ;;
esac
if [ -L "$TARGET" ]; then
  echo "ERROR: $TARGET is a symlink; refusing to replace it." >&2
  exit 2
fi
if [ ! -f "$TARGET" ]; then
  echo "ERROR: $TARGET does not exist; refusing to create it without a baseline." >&2
  exit 2
fi

CURRENT=$(cat "$TARGET" 2>/dev/null || true)
case "$CURRENT" in
  "null,null,null"|"") ;;
  *",250,01")
    CURRENT_ICCID=${CURRENT%,250,01}
    if [ "$CURRENT_ICCID" = "$EXPECTED_ICCID" ]; then
      echo "Target already contains the supplied MTS triplet; no change required."
      exit 0
    fi
    echo "ERROR: a different ICCID is already paired with the MTS triplet; refusing to overwrite." >&2
    exit 3
    ;;
  *)
    echo "ERROR: current file is neither neutral nor the supplied MTS value; refusing to overwrite." >&2
    exit 3
    ;;
esac

mkdir -p "$BACKUP_DIR"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_DIR/iccid_0.$TS.$$.bak"
TMP="$TARGET.rmx3701.$TS.$$.tmp"
RESTORE="$TARGET.rmx3701.$TS.$$.restore"

KEEP_RESTORE=0
cleanup() {
  rm -f "$TMP"
  if [ "$KEEP_RESTORE" -eq 0 ]; then
    rm -f "$RESTORE"
  fi
}
trap cleanup EXIT INT TERM

cp -p "$TARGET" "$BACKUP"
chmod 0600 "$BACKUP"
if ! cmp -s "$TARGET" "$BACKUP"; then
  echo "ERROR: backup verification failed; target was not changed." >&2
  exit 4
fi

printf '%s,250,01' "$EXPECTED_ICCID" > "$TMP"
chown radio:radio "$TMP"
chmod 0600 "$TMP"
if ! chcon "$EXPECTED_CONTEXT" "$TMP"; then
  echo "ERROR: SELinux relabel failed; target was not changed." >&2
  exit 5
fi

TMP_META=$(stat -c '%U:%G %a' "$TMP" 2>/dev/null || true)
if [ "$TMP_META" != "radio:radio 600" ]; then
  echo "ERROR: staged file owner/mode verification failed; target was not changed." >&2
  exit 6
fi
if ! ls -Z "$TMP" 2>/dev/null | grep -Fq "$EXPECTED_CONTEXT"; then
  echo "ERROR: staged SELinux context verification failed; target was not changed." >&2
  exit 7
fi
STAGED_VALUE=$(cat "$TMP" 2>/dev/null || true)
if [ "$STAGED_VALUE" != "$EXPECTED_ICCID,250,01" ]; then
  echo "ERROR: staged content verification failed; target was not changed." >&2
  exit 8
fi

if ! mv "$TMP" "$TARGET"; then
  echo "ERROR: atomic replacement failed; original target should remain unchanged." >&2
  exit 9
fi

FINAL_VALUE=$(cat "$TARGET" 2>/dev/null || true)
FINAL_META=$(stat -c '%U:%G %a' "$TARGET" 2>/dev/null || true)
if [ "$FINAL_VALUE" != "$EXPECTED_ICCID,250,01" ] ||
   [ "$FINAL_META" != "radio:radio 600" ] ||
   ! ls -Z "$TARGET" 2>/dev/null | grep -Fq "$EXPECTED_CONTEXT"; then
  echo "ERROR: post-write verification failed; attempting automatic restoration." >&2
  if ! cp -p "$BACKUP" "$RESTORE"; then
    KEEP_RESTORE=1
    echo "CRITICAL: could not stage automatic restore; keep backup at $BACKUP and restore candidate at $RESTORE." >&2
    exit 10
  fi
  if ! chown radio:radio "$RESTORE" || ! chmod 0600 "$RESTORE" || ! chcon "$EXPECTED_CONTEXT" "$RESTORE"; then
    KEEP_RESTORE=1
    echo "CRITICAL: restore staging metadata failed; keep backup at $BACKUP and restore candidate at $RESTORE." >&2
    exit 10
  fi
  if ! mv "$RESTORE" "$TARGET"; then
    KEEP_RESTORE=1
    echo "CRITICAL: could not replace target with backup; keep backup at $BACKUP and restore candidate at $RESTORE." >&2
    exit 10
  fi
  RESTORED_META=$(stat -c '%U:%G %a' "$TARGET" 2>/dev/null || true)
  if cmp -s "$TARGET" "$BACKUP" &&
     [ "$RESTORED_META" = "radio:radio 600" ] &&
     ls -Z "$TARGET" 2>/dev/null | grep -Fq "$EXPECTED_CONTEXT"; then
    echo "Original target content and metadata restored and verified."
  else
    echo "CRITICAL: restored target did not pass verification; keep backup at $BACKUP." >&2
    exit 10
  fi
  exit 11
fi

echo "MTS triplet written and verified. Backup retained at $BACKUP."
echo "No radio service was restarted and no reboot was performed."
