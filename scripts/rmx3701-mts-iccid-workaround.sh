#!/system/bin/sh
# Explicit, opt-in MTS-only helper for Realme GT Neo 5 SE (RMX3701).
# This is NOT installed as a KernelSU service and never runs automatically.
# It changes /data/vendor/radio/iccid_0; use only with a verified backup.
set -eu
TARGET=/data/vendor/radio/iccid_0
BACKUP_DIR=/data/local/tmp/rmx3701-ims-backup
EXPECTED_ICCID=${RMX3701_MTS_ICCID:-}
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

MODEL=$(getprop ro.product.device)
VENDOR_MODEL=$(getprop ro.product.vendor.device)
FINGERPRINT=$(getprop ro.build.fingerprint)
case "$MODEL $VENDOR_MODEL $FINGERPRINT" in
  *RMX3701*) ;;
  *) echo "ERROR: target identity not confirmed (model=$MODEL vendor=$VENDOR_MODEL)." >&2; exit 2 ;;
esac

if [ "$FORCE" -ne 1 ]; then
  echo "ERROR: opt-in changes require a second explicit argument: --force" >&2
  echo "Usage: RMX3701_MTS_ICCID=<digits> sh $0 --force" >&2
  exit 2
fi
if [ -z "$EXPECTED_ICCID" ]; then
  echo "ERROR: set RMX3701_MTS_ICCID locally; do not commit a real ICCID." >&2
  exit 2
fi
case "$EXPECTED_ICCID" in *[!0-9]*) echo "ERROR: ICCID must contain decimal digits only." >&2; exit 2;; esac
if [ ! -f "$TARGET" ]; then
  echo "ERROR: $TARGET does not exist; refusing to create it without a baseline." >&2
  exit 2
fi

mkdir -p "$BACKUP_DIR"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_DIR/iccid_0.$TS.bak"
cp -p "$TARGET" "$BACKUP"
echo "Backup: $BACKUP"
CURRENT=$(cat "$TARGET" 2>/dev/null || true)
case "$CURRENT" in
  "null,null,null"|"") ;;
  *",250,01")
    echo "Current file already contains an MTS triplet; no change made."
    exit 0
    ;;
  *)
    echo "ERROR: current file is neither neutral nor known MTS format; refusing to overwrite." >&2
    echo "Inspect the backup and current file before any manual intervention." >&2
    exit 3
    ;;
esac
TMP="$TARGET.rmx3701.tmp"
trap 'rm -f "$TMP"' EXIT
printf '%s,250,01' "$EXPECTED_ICCID" > "$TMP"
chown radio:radio "$TMP"
chmod 0600 "$TMP"
chcon u:object_r:vendor_radio_vendor_data_file:s0 "$TMP" 2>/dev/null || true
mv "$TMP" "$TARGET"
trap - EXIT
echo "Changed $TARGET to the supplied ICCID and MTS PLMN. No service was restarted."
echo "A reboot is not performed automatically; test only after reviewing the backup."
