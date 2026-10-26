# Upstream research retained for RMX3701

The originating project is a Sailfish OS port for Lenovo Vibe K6 Note/Plus (Qualcomm MSM8937, Android 11/hybris base). Its scripts rely on that system's filesystem, QCRIL database path, Python installation, DIAG tooling, service manager, and staging directory.

## Useful concepts retained

- QCRIL's MBN selection tables are managed state. Replacing or deleting the live database may remove emergency/operator tables.
- File presence alone does not prove selection or activation.
- Validate each stage independently: MBN discovery, QCRIL indexing, carrier selection, modem acceptance/activation, and IMS registration.
- Maintain a reversible path to stock state.

## Not portable without a device-specific rewrite

- `/data/vendor/radio/qcril.db` (RMX3701 uses `/data/vendor/radio/qcrilNr.db`).
- `/data/vendor/radio/modem_config/mcfg_sw` (RMX3701 MBN was observed under `/data/vendor/modem_config/mcfg_sw`).
- `/home/defaultuser`, `/usr/bin/python3`, upstream `diagcat.py`, Sailfish's `ril-daemon`, QMI/DIAG node names, or upstream fallback carrier profiles.
- Donor MBNs and retargeting values for Jio/BSNL/UK networks.

No upstream mutation script should be run on RMX3701 unchanged.
