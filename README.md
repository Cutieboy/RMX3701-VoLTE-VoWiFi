# RMX3701 VoLTE / VoWiFi recovery

**Target device:** Realme GT Neo 5 SE (`RMX3701` / `RE58D1L1`)  
**Platform:** Qualcomm SM7475, arm64  
**Tested system:** Android 16 / Realme UI 7.0, build `RMX3701_16.0.5.1300(EX01)`  
**Known working carrier:** MTS Russia (MCC 250, MNC 01)

This repository is a focused, device-specific toolkit for understanding and recovering Qualcomm MBN/IMS profile selection on RMX3701. It is **not** a ROM port, firmware flasher, or universal VoLTE unlocker.

> **Important:** This is an experimental community project. The RMX3701 has achieved working VoLTE and VoWiFi, but the exact causal contribution of each workaround has not been isolated. Do not treat every workaround as a proven universal repair.

## Current findings on RMX3701

- The device firmware includes an MTS software MBN at `/data/vendor/modem_config/mcfg_sw/generic/Russia/MTS/Commercial/RU/mcfg_sw.mbn`.
- The live QCRIL database is `/data/vendor/radio/qcrilNr.db` (not the `qcril.db` used by the upstream karatep project).
- A prior diagnostic run reported empty software-MBN indexing tables and `No MBN file selected`.
- VoLTE and VoWiFi started working after a persistent KernelSU service script rewrote `/data/vendor/radio/iccid_0` to `<ICCID>,250,01` and the device was rebooted. This is an observed correlation, not proof that the file alone caused the fix.
- A duplicate Oplus VoWiFi Fix module directory with a leading BOM character was disabled; VoLTE, VoWiFi, Mouse VPN and Batman VPN remained working after reboot.

## What this repository does — and does not do

It provides concise RMX3701-specific documentation, a **read-only** ADB/PowerShell diagnostic collector, an explicitly invoked backup-aware MTS `iccid_0` helper, and notes about adapting the upstream research.

It does **not** insert guessed rows into `qcrilNr.db`, rewrite arbitrary MBN files, modify modem NV/EFS, flash modem partitions, blindly restart RIL/QCRIL services, or claim that changing `iccid_0` is the universal solution for all carriers.

## Quick start (Windows PowerShell 7 + ADB over Wi-Fi)

Confirm ADB connectivity:

```powershell
adb devices -l
```

Run the read-only diagnostic collector:

```powershell
.\tools\collect-rmx3701.ps1
```

The report is written to `reports\rmx3701-diagnostic-<timestamp>.txt`. Review and redact SIM identifiers before sharing it.

## MTS `iccid_0` workaround

The experimental helper is documented at [scripts/rmx3701-mts-iccid-workaround.sh](scripts/rmx3701-mts-iccid-workaround.sh). It is **not run automatically** and must be invoked explicitly. It refuses to overwrite an unrelated non-empty value and creates a backup first. Do not enable it for another carrier without understanding that carrier's `iccid_0` format on this firmware.

## Safety

- Back up `/data/vendor/radio/qcrilNr.db` and check for WAL/SHM sidecars before any future database operation. Never replace the live database with a vendor template and never delete it as a shortcut.
- Do not reuse upstream karatep scripts that assume Sailfish OS, `/data/vendor/radio/qcril.db`, `/data/vendor/radio/modem_config/mcfg_sw`, `/usr/bin/python3`, `/home/defaultuser`, `diagcat.py`, or the `ril-daemon` service. RMX3701 uses different paths and service names that must be verified independently.
- Do not flash `modem_a`/`modem_b` as part of this toolkit.
- Do not write QMI/NV/EFS data from scripts unless a separate operation-specific design, backup, validation and rollback plan exists.
- The owner's real ICCID must not be committed into public repository history.

## Upstream

This repository was derived from MBN/IMS research in [sailfish-on-karatep/karatep-port](https://github.com/sailfish-on-karatep/karatep-port), especially its MBN-selection analysis. The upstream device is a Lenovo Vibe K6 Note/Plus running Sailfish OS; its executable scripts are **not directly compatible with RMX3701**.

## Scope

Prefer small, reviewable changes. Each script must say whether it is read-only, backs up state, or mutates the device. Potentially destructive modem/database operations must be opt-in and include a tested rollback path. Do not add generic ROM-building, Waydroid, flashing, or unrelated hardware-debugging material here.
