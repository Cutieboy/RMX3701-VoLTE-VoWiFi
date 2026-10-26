# Read-only diagnostic collector for RMX3701. Windows PowerShell 7 + ADB.
# No device state changes. Sensitive ICCID content is intentionally NOT collected.
$ErrorActionPreference = 'Stop'
$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) { throw 'adb.exe is not on PATH.' }
$devices = & adb devices -l
if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
$model = (& adb shell getprop ro.product.device).Trim()
$vendorModel = (& adb shell getprop ro.product.vendor.device).Trim()
$fingerprint = (& adb shell getprop ro.build.fingerprint).Trim()
if (($model -notmatch 'RMX3701|RE58D1L1') -and ($vendorModel -notmatch 'RMX3701|RE58D1L1') -and ($fingerprint -notmatch 'RMX3701')) {
    throw "Target verification failed. model='$model'; vendorModel='$vendorModel'; fingerprint='$fingerprint'."
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $root 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$out = Join-Path $reportDir "rmx3701-diagnostic-$stamp.txt"
function Section([string]$Title) { Add-Content -LiteralPath $out -Value "`n===== $Title =====" }
function AddLines($Lines) { $Lines | Out-String -Width 260 | Add-Content -LiteralPath $out }
function AdbRemote([string]$Command) {
    $result = & adb shell $Command 2>&1
    if ($LASTEXITCODE -ne 0) { return @("ERROR exit=$LASTEXITCODE", $result) }
    return $result
}
Add-Content -LiteralPath $out -Value "RMX3701 read-only report; timestamp=$(Get-Date -Format o)"
Section 'ADB devices'; AddLines $devices
Section 'Build identity'
AddLines @(
 "model=$model",
 "vendor_model=$vendorModel",
 "fingerprint=$fingerprint",
 "incremental=$((& adb shell getprop ro.build.version.incremental).Trim())",
 "baseband=$((& adb shell getprop gsm.version.baseband).Trim())",
 "slot_suffix=$((& adb shell getprop ro.boot.slot_suffix).Trim())"
)
Section 'MBN properties and operator'
AddLines (AdbRemote "getprop persist.vendor.radio.sw_mbn_loaded")
AddLines (AdbRemote "getprop persist.vendor.radio.sw_mbn_update")
AddLines (AdbRemote "getprop persist.vendor.radio.mbn_path")
AddLines (AdbRemote "getprop gsm.sim.operator.numeric")
Section 'File metadata (missing files are expected on some builds)'
AddLines (AdbRemote "su -c 'ls -lZ /data/vendor/radio/qcrilNr.db /data/vendor/radio/qcrilNr.db-wal /data/vendor/radio/qcrilNr.db-shm /data/vendor/radio/iccid_0 /data/vendor/modem_config/mcfg_sw/generic/Russia/MTS/Commercial/RU/mcfg_sw.mbn 2>&1'")
Section 'Hashes'
AddLines (AdbRemote "su -c 'sha256sum /data/vendor/radio/qcrilNr.db /data/vendor/radio/iccid_0 2>&1'")
Section 'QCRIL and IMS logs (filtered on Windows)'
$logs = AdbRemote "logcat -d -b radio -b main -b system"
$filtered = $logs | Select-String -Pattern 'sw.mbn|reevaluation|qcril_sw_mbn|No MBN file selected|Selected config|pdc.*select|pdc.*activat|no such table|ims_reg|IMS.*registr' -CaseSensitive:$false
AddLines $filtered
Section 'Telephony registry and connectivity'
AddLines (AdbRemote 'dumpsys telephony.registry')
AddLines (AdbRemote 'dumpsys connectivity')
Write-Host "Saved report: $out"
Write-Warning 'Review/redact IMSI, ICCID, phone numbers, and network identifiers before sharing the report.'
