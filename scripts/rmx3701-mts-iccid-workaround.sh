#!/system/bin/sh
# Explicit, opt-in MTS-only helper for RMX3701.
# Not installed as a service and does not run at boot.
set -eu
TARGET=/data/vendor/radio/iccid_0
BACKUP_DIR=/data/local/tmp/rmx3701-ims-backup
EXPECTED_ICCID=${RMX3701_MTS_ICCID:-}
if [ "$(getprop ro.product.device)" != RMX3701 ] && [ "$(getprop ro.product.vendor.device)" != RMX3701 ]; then
    echo 'ERROR: intended only for RMX3701.' >&2; exit 2
fi
if [ -z "$EXPECTED_ICCID" ]; then
    echo 'ERROR: set RMX3701_MTS_ICCID to the SIM ICCID in the local shell environment.' >&2
    echo 'The repository intentionally does not contain a real ICCID.' >&2; exit 2
fi
case "$EXPECTED_ICCID" in *[!0-9]*) echo 'ERROR: ICCID must contain decimal digits only.' >&2; exit 2;; esac
if [ ! -e "$TARGET" ]; then echo 'ERROR: iccid_0 is missing; refusing to create it without a baseline.' >&2; exit 2; fi
mkdir -p "$BACKUP_DIR"
TS=$(date +%Y%m%d-%H%M%S)
cp -p "$TARGET" "$BACKUP_DIR/iccid_0.$TS.bak"
echo "Backup: $BACKUP_DIR/iccid_0.$TS.bak"
CURRENT=$(cat "$TARGET" 2>/dev/null || true)
case "$CURRENT" in
  'null,null,null'|'') ;;
  *',250,01') echo 'File already contains MTS PLMN triplet; no change made.'; exit 0;;
  *) echo 'ERROR: current value is not neutral or MTS format; refusing automatic overwrite.' >&2; exit 3;;
esac
TMP="$TARGET.rmx3701.tmp"
printf '%s,250,01' "$EXPECTED_ICCID" > "$TMP"
chown radio:radio "$TMP"
chmod 0600 "$TMP"
chcon u:object_r:vendor_radio_vendor_data_file:s0 "$TMP" 2>/dev/null || true
mv "$TMP" "$TARGET"
echo "Wrote MTS triplet to $TARGET. No service was restarted."
echo 'Do not reboot until you have separately decided to test this change.'
