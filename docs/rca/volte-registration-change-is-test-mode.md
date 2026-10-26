# Upstream MBN/IMS research: context only

The original upstream document describes a different device (Lenovo Vibe K6 Note/Plus), Qualcomm MSM8937, Sailfish OS and a legacy RIL stack. It is retained solely as background research. **Its device-specific findings and scripts are not validated for Realme RMX3701.**

For RMX3701-specific findings, current state, limitations and next steps, see [RMX3701_FINDINGS.md](../RMX3701_FINDINGS.md).

Do not run the original scripts against RMX3701 without independently porting and validating paths, schema, service names, MBN format assumptions, and rollback behavior. In particular, RMX3701 uses `/data/vendor/radio/qcrilNr.db`, and the MTS MBN was observed under `/data/vendor/modem_config/mcfg_sw/`; the original project uses different paths and assumptions.

The upstream source is [sailfish-on-karatep/karatep-port](https://github.com/sailfish-on-karatep/karatep-port).
