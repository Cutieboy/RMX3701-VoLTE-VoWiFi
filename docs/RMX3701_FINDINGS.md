# RMX3701 MBN / IMS findings

## Device under test

- Realme GT Neo 5 SE, RMX3701 / RE58D1L1
- Qualcomm SM7475
- Android 16 / Realme UI 7.0
- Firmware `RMX3701_16.0.5.1300(EX01)`
- Root: KernelSU Next, LKM; SELinux Enforcing

## Device-specific facts collected so far

- Live QCRIL database: `/data/vendor/radio/qcrilNr.db`.
- A backup was observed at `/data/vendor/radio/qcrilNr.db.bak_working`.
- MTS MBN path: `/data/vendor/modem_config/mcfg_sw/generic/Russia/MTS/Commercial/RU/mcfg_sw.mbn`.
- The MTS MBN was observed at 48,816 bytes and previously matched SHA-256 `31e2b2bfa09894159e85b628a3e0ff65644c2b98f31d0cd750d9bd73dfa7c25c`.
- A service script wrote `/data/vendor/radio/iccid_0` in the format `<ICCID>,250,01`; after reboot, VoLTE/VoWiFi worked.
- At one diagnostic point `persist.vendor.radio.sw_mbn_loaded` returned `true`, `persist.vendor.radio.sw_mbn_update` was unset, and `persist.vendor.radio.mbn_path` returned `/data/vendor/modem_config/`.
- A previous report stated QCRIL's software-MBN indexing tables were empty despite the MTS MBN existing. Revalidate this against a consistent database snapshot before attempting repair.

## Outcome

After installing a KernelSU `service.d` trigger that restored the MTS triplet in `iccid_0`, then rebooting, the owner verified VoLTE, VoWiFi, Mouse VPN and Batman VPN. A duplicate Oplus VoWiFi Fix directory with a leading BOM character was also disabled; the same features still worked after reboot.

The causal mechanism has not been isolated because multiple changes occurred. Do not claim the trigger alone is conclusively responsible.

## Unresolved questions

1. Does normal Android boot already populate `iccid_0` correctly, and does the trigger merely prevent a race?
2. Are the QCRIL MBN tables still empty, or did they repopulate after reboot?
3. What is the correct RMX3701-specific service reload/re-evaluation mechanism? Do not assume upstream `ctl.restart ril-daemon` applies.
4. What schema and fields are required by this firmware's `qcrilNr.db`? Verify against the live database and binary logic before constructing rows.
5. Is the `iccid_0` format stable for other carriers? Not established.
6. Did the modem_a/modem_b version mismatch hypothesis matter? Not proven; no modem partition flashing was performed during the confirmed recovery.

## Operational rules

- Read-only first; create verified backups before writes.
- Never delete or replace `qcrilNr.db` blindly. Check WAL/SHM sidecars.
- Do not invent MBN metadata values or assume MNC padding from another build.
- Keep MTS-specific behavior clearly labelled.
- Successful calling does not prove the full root cause of MBN index generation.

## 2026-11-24 read-only post-reboot recheck

[CONFIRMED] ADB connected to `192.168.1.195:5555`; product RMX3701 / RE58D1L1. Build display `RMX3701_16.0.5.1300(EX01)`, Android 16, security patch 2026-09-01, baseband `Q_V1_P14`. Operator property `25001,40102` includes MTS PLMN 25001.

[CONFIRMED] Current radio properties at this audit: `persist.vendor.radio.sw_mbn_loaded` was empty/unset; `persist.vendor.radio.sw_mbn_update=true`; `persist.vendor.radio.mbn_path=/data/vendor/modem_config/`. This supersedes the older property snapshot above; property values can change across boots and must be rechecked before a future action.

[CONFIRMED] Both `/data/adb/service.d/00_adbtcpport.sh` and `01_mts_mbn_trigger.sh` exist by metadata. The latter contains a private subscriber identifier on the live device; do not copy it into public source, reports or handoffs.

[CONFIRMED] The only Oplus VoWiFi module directory returned by the current module listing is the BOM-prefixed `﻿oplus_vowifi_unlock`; its `disable` marker exists. The standard-named `oplus_vowifi_unlock` directory was absent at this check. The owner reports VoLTE, VoWiFi, Mouse VPN and Batman VPN all remain working after reboot.

[UNRESOLVED] The successful state followed several simultaneous changes and reboot. Do not attribute it solely to the ICCID trigger, MBN property, module disable or reboot without a controlled, owner-approved test. Preserve the current state while functional.
