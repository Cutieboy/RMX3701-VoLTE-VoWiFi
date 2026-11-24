# Read-only RMX3701 collector. Windows PowerShell 5.1+ and ADB.
# Output is sanitized before it is written. No raw telephony log or ICCID-derived hash is saved.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Device
)

$ErrorActionPreference = 'Stop'
$adbCommand = Get-Command adb -ErrorAction Stop
$script:AdbPath = $adbCommand.Source

# Resolve a single exact ADB target. When -Device is omitted, ambiguity is fatal.
$deviceRows = @(& $script:AdbPath devices -l 2>&1 | ForEach-Object { "$_" } |
    Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
if ($LASTEXITCODE -ne 0) { throw 'adb devices -l failed.' }

if ([string]::IsNullOrWhiteSpace($Device)) {
    if ($deviceRows.Count -ne 1) {
        throw "Expected exactly one online ADB device; found $($deviceRows.Count). Supply -Device <serial>."
    }
    $script:Device = ($deviceRows[0] -split '\s+')[0]
}
else {
    $matches = @($deviceRows | Where-Object { (($_ -split '\s+')[0]) -ceq $Device })
    if ($matches.Count -ne 1) {
        throw "The requested ADB serial is not uniquely online. Check 'adb devices -l' and retry with the exact -Device serial."
    }
    $script:Device = $Device
}

function Invoke-TargetAdb {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )
    $output = @(& $script:AdbPath -s $script:Device @Arguments 2>&1 | ForEach-Object { "$_" })
    $exitCode = $LASTEXITCODE
    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        throw "ADB command failed (exit $exitCode): adb -s <selected-device> $($Arguments -join ' ')"
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines = $output
    }
}

function Get-RedactedLine {
    param([AllowEmptyString()][string]$Line)
    $value = $Line

    # Subscriber / personal identifiers and IMS identities.
    $value = [regex]::Replace($value, '(?i)\b(ICCID|IMSI|IMEI|MEID|MSISDN|phoneNumber|mCallIncomingNumber|line1Number|mIccId|mImsi)\b(\s*[:=]\s*)[^\s,;}\]]+', '$1$2[REDACTED]')
    $value = [regex]::Replace($value, '(?i)\b(sip|sips|tel):[^\s,;}\]]+', '[REDACTED_IMS_IDENTITY]')
    $value = [regex]::Replace($value, '(?<!\d)(?:\+?\d[\s().-]*){10,}(?!\d)', '[REDACTED_PHONE_OR_ID]')
    $value = [regex]::Replace($value, '(?<!\d)\d{15,}(?!\d)', '[REDACTED_LONG_ID]')

    # Cell / network identifiers that are not required for the summary.
    $value = [regex]::Replace($value, '(?i)\b(mCi|mPci|mTac|mEarfcn|mLac|mCid|mBsic|mNetworkId|mSystemId|cellId|cellIdentity|lac|tac|nci|arfcn)\b(\s*[:=]\s*)[^\s,;}\]]+', '$1$2[REDACTED]')
    $value = [regex]::Replace($value, '(?i)\b(SSID|BSSID)\b(\s*[:=]\s*)[^,;\r\n]+', '$1$2[REDACTED]')

    # MAC and IPv4.
    $value = [regex]::Replace($value, '(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}', '[REDACTED_MAC]')
    $value = [regex]::Replace($value, '(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)', '[REDACTED_IPv4]')

    # IPv6: validate candidate strings before replacement to avoid masking ordinary text.
    $ipv6Pattern = '(?i)(?<![0-9a-f:])(?:[0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}(?:/\d{1,3})?(?![0-9a-f:])'
    $ipv6Matches = [regex]::Matches($value, $ipv6Pattern)
    for ($i = $ipv6Matches.Count - 1; $i -ge 0; $i--) {
        $match = $ipv6Matches[$i]
        $candidate = $match.Value -replace '/\d{1,3}$', ''
        try {
            $parsed = [System.Net.IPAddress]::Parse($candidate)
            if ($parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
                $value = $value.Remove($match.Index, $match.Length).Insert($match.Index, '[REDACTED_IPv6]')
            }
        }
        catch { }
    }
    return $value
}

$report = New-Object 'System.Collections.Generic.List[string]'
function Add-Section {
    param([string]$Name)
    [void]$script:report.Add('')
    [void]$script:report.Add("===== $Name =====")
}
function Add-SafeLines {
    param(
        [string[]]$Lines,
        [int]$Maximum = 200
    )
    $count = 0
    foreach ($line in $Lines) {
        if ($count -ge $Maximum) { break }
        [void]$script:report.Add((Get-RedactedLine -Line $line))
        $count++
    }
    if ($Lines.Count -gt $Maximum) {
        [void]$script:report.Add("[TRUNCATED: first $Maximum matching lines retained]")
    }
}

# Verify model identity before creating any report.
$model = (Invoke-TargetAdb -Arguments @('shell', 'getprop', 'ro.product.device')).Lines -join ''
$vendorModel = (Invoke-TargetAdb -Arguments @('shell', 'getprop', 'ro.product.vendor.device')).Lines -join ''
$fingerprint = (Invoke-TargetAdb -Arguments @('shell', 'getprop', 'ro.build.fingerprint')).Lines -join ''
if (("$model $vendorModel $fingerprint") -notmatch 'RMX3701|RE58D1L1') {
    throw 'Target verification failed: selected ADB device is not identified as RMX3701 / RE58D1L1.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $projectRoot 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$out = Join-Path $reportDir "rmx3701-diagnostic-$stamp.txt"

[void]$report.Add("RMX3701 sanitized read-only report; timestamp=$(Get-Date -Format o)")
[void]$report.Add("Selected target: RMX3701 / RE58D1L1 (serial intentionally omitted)")
[void]$report.Add('Privacy: subscriber identifiers, phone numbers, IMS identities, cell IDs and network addresses are redacted before saving.')

Add-Section 'Build identity'
$buildKeys = @(
    'ro.product.device',
    'ro.product.vendor.device',
    'ro.build.fingerprint',
    'ro.build.version.incremental',
    'gsm.version.baseband',
    'ro.boot.slot_suffix',
    'ro.telephony.sim.count',
    'persist.radio.multisim.config'
)
foreach ($key in $buildKeys) {
    $r = Invoke-TargetAdb -Arguments @('shell', 'getprop', $key)
    [void]$report.Add("$key=$($r.Lines -join '')")
}

Add-Section 'MBN properties and operator'
foreach ($key in @(
    'persist.vendor.radio.sw_mbn_loaded',
    'persist.vendor.radio.sw_mbn_update',
    'persist.vendor.radio.mbn_path',
    'gsm.sim.state',
    'gsm.sim.operator.numeric',
    'gsm.operator.numeric'
)) {
    $r = Invoke-TargetAdb -Arguments @('shell', 'getprop', $key) -AllowFailure
    [void]$report.Add("$key=$($r.Lines -join '')")
}

Add-Section 'WFC user settings'
foreach ($key in @('wfc_ims_enabled', 'wfc_ims_mode', 'wfc_ims_roaming_enabled')) {
    $r = Invoke-TargetAdb -Arguments @('shell', 'settings', 'get', 'global', $key) -AllowFailure
    [void]$report.Add("global.$key=$($r.Lines -join '')")
}
[void]$report.Add('Note: Android stores WFC preferences per subscription on many builds; global settings alone do not identify the enabled SIM.')

Add-Section 'Carrier WFC configuration'
$carrierConfig = Invoke-TargetAdb -Arguments @('shell', 'dumpsys', 'carrier_config') -AllowFailure
$carrierPatterns = 'carrier_wfc_ims_available_bool|carrier_wfc_supports_wifi_only_bool|carrier_default_wfc_ims_enabled_bool|carrier_default_wfc_ims_mode_int|carrier_default_wfc_ims_roaming_mode_int|mConfigFromDefaultApp|^\s*25001\s*='
$carrierLines = @($carrierConfig.Lines | Where-Object { $_ -match $carrierPatterns })
Add-SafeLines -Lines $carrierLines -Maximum 100

Add-Section 'File metadata (no file contents or hashes)'
$metadataCommand = "ls -lZ /data/vendor/radio/qcrilNr.db /data/vendor/radio/qcrilNr.db-wal /data/vendor/radio/qcrilNr.db-shm /data/vendor/radio/iccid_0 /data/vendor/modem_config/mcfg_sw/generic/Russia/MTS/Commercial/RU/mcfg_sw.mbn 2>&1"
$metadata = Invoke-TargetAdb -Arguments @('shell', 'su', '-c', $metadataCommand) -AllowFailure
Add-SafeLines -Lines $metadata.Lines -Maximum 20
if ($metadata.ExitCode -ne 0) {
    [void]$report.Add("[INFO] One or more optional paths may be absent; inspect the lines above.")
}

Add-Section 'Filtered QCRIL / IMS logs (sanitized)'
$logs = Invoke-TargetAdb -Arguments @('shell', 'logcat', '-d', '-b', 'radio', '-b', 'main', '-b', 'system', '-t', '3000') -AllowFailure
$filteredLogs = @($logs.Lines | Select-String -Pattern 'sw.mbn|reevaluation|qcril_sw_mbn|No MBN file selected|Selected config|pdc.*select|pdc.*activat|no such table|ims_reg|IMS.*registr|ImsRegistration|imsFeatureCreated' -CaseSensitive:$false | ForEach-Object { $_.Line })
Add-SafeLines -Lines $filteredLogs -Maximum 250

Add-Section 'Telephony registry summary (sanitized)'
$registry = Invoke-TargetAdb -Arguments @('shell', 'dumpsys', 'telephony.registry') -AllowFailure
$registryPatterns = 'Phone Id=|mVoiceRegState=|mDataRegState=|getRilVoiceRadioTechnology=|getRilDataRadioTechnology=|mIsIwlanPreferred=|mIsImsRegistered|mImsRegistration|registrationState=|availableServices=|mWfc|WifiCalling|WiFiCalling'
$registryLines = @($registry.Lines | Select-String -Pattern $registryPatterns | ForEach-Object { $_.Line })
Add-SafeLines -Lines $registryLines -Maximum 120

# UTF-8 without BOM; only sanitized data reaches the report file.
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($out, $report.ToArray(), $encoding)
Write-Host "Saved sanitized report: $out"
Write-Host "Selected ADB target verified as RMX3701; serial omitted from report."
Write-Warning 'Review the sanitized report before sharing. No ICCID contents or ICCID-derived hashes are collected.'
