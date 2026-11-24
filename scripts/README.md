# RMX3701 tooling

This directory is limited to Realme GT Neo 5 SE / RMX3701 MBN and IMS recovery helpers.

- `rmx3701-mts-iccid-workaround.sh`: MTS-only opt-in mutator. Requires an explicitly supplied 19- or 20-digit ICCID and `--force`. It is not installed persistently and must never be run as part of routine diagnosis. It checks the target identity, existing value, backup, staged ownership/mode/SELinux context, and final read-back. It was syntax-checked only; the live mutation has not been executed during this review.
- `../tools/collect-rmx3701.ps1`: read-only PowerShell + ADB collector. Uses `-Device <serial>` for explicit selection, requires exactly one online device if omitted, pins every command to the selected serial, does not hash or read `iccid_0`, and sanitizes the report before saving. Generated reports are git-ignored.

The upstream Sailfish build, flashing, Waydroid, generic QMI/EFS mutation, and unrelated hardware-porting scripts are not included. The MBN selection concepts remain documented, while writes to modem configuration or NV/EFS require a separate device-verified implementation.
