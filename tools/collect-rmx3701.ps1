# Read-only diagnostic collection for Realme GT Neo 5 SE (RMX3701).
# Requires Windows PowerShell 7 and adb on PATH. No device state is modified.
$ErrorActionPreference = 'Stop'
$devices = & adb devices -l
if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
$model = (& adb shell getprop ro.product.device).Trim()
$vendorModel = (& adb shell getprop ro.product.vendor.device).Trim()
if (($model -notmatch 'RMX3701|RE58D1L1') -and ($vendorModel -notmatch 'RMX3701|RE58D1L1')) {
    throw "Device identity did not match RMX3701/RE58D1L1 (reported: '$model', vendor: '$vendorModel'). Aborting."
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $root 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$out = Join-Path $reportDir "rmx3701-diagnostic-$stamp.txt"

function Add-Section([string]$Title, [scriptblock]$Command) {
    Add-Content -LiteralPath $out -Value "`n===== $Title ====="
    try { $text = & $Command 2>&1 | Out-String -Width 260; Add-Content -LiteralPath $out -Value $text }
    catch { Add-Content -LiteralPath $out -Value "ERROR: $($_.Exception.Message)" }
}

Add-Content -LiteralPath $out -Value "RMX3701 read-only diagnostic; timestamp: $(Get-Date -Format o)"
Add-Section 'ADB devices' { & adb devices -l }
Add-Section 'Build' {
    "device=$(& adb shell getprop ro.product.device)"
    "vendor_device=$(& adb shell getprop ro.product.vendor.device)"
    "fingerprint=$(& adb shell getprop ro.build.fingerprint)"
    "incremental=$(& adb shell getprop ro.build.version.incremental)"
    "baseband=$(& adb shell getprop gsm.version.baseband)"
    "slot=$(& adb shell getprop ro.boot.slot_suffix)"
}
Add-Section 'MBN properties' {
    "sw_mbn_loaded=$(& adb shell getprop persist.vendor.radio.sw_mbn_loaded)"
    "sw_mbn_update=$(& adb shell getprop persist.vendor.radio.sw_mbn_update)"
    "mbn_path=$(& adb shell getprop persist.vendor.radio.mbn_path)"
    "operator_numeric=$(& adb shell getprop gsm.sim.operator.numeric)"
}
Add-Section 'Key file metadata' {
    & adb shell "su -c 'ls -lZ /data/vendor/radio/qcrilNr.db /data/vendor/radio/qcrilNr.db-wal /data/vendor/radio/qcrilNr.db-shm /data/vendor/radio/iccid_0 /data/vendor/modem_config/mcfg_sw/generic/Russia/MTS/Commercial/RU/mcfg_sw.mbn'"
}
Add-Section 'Database and ICCID hashes' { & adb shell "su -c 'sha256sum /data/vendor/radio/qcrilNr.db /data/vendor/radio/iccid_0'" }
Add-Section 'ICCID file content (sensitive; redact before sharing)' { & adb shell "su -c 'cat /data/vendor/radio/iccid_0'" }
Add-Section 'Relevant radio log lines' {
    $logs = & adb shell "su -c 'logcat -d -b radio -b main -b system'"
    $logs | Select-String -Pattern 'sw.mbn|reevaluation|MTS_Russia|qcril_sw_mbn|pdc.*select|pdc.*activat|no such table|ims_reg|IMS.*registr' -CaseSensitive:$false
}
Add-Section 'IMS/connectivity snapshot' { & adb shell 'dumpsys telephony.registry'; & adb shell 'dumpsys connectivity' }
Write-Host "Report saved to: $out"
Write-Warning 'The report contains SIM-sensitive data. Redact ICCID/IMSI/phone numbers before publishing.'
