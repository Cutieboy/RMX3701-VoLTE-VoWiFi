# RMX3701 tooling

This directory is limited to Realme GT Neo 5 SE / RMX3701 MBN and IMS recovery helpers.

- `rmx3701-mts-iccid-workaround.sh`: opt-in MTS-only helper; not installed persistently.
- `../tools/collect-rmx3701.ps1`: read-only diagnostic collector for Windows PowerShell and ADB.

The upstream Sailfish build, flashing, Waydroid, generic QMI/EFS mutation, and unrelated hardware-porting scripts are not included. The MBN selection concepts remain documented, while writes to modem configuration or NV/EFS require a separate device-verified implementation.
