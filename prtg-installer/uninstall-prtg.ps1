<#
.SYNOPSIS
    Clean uninstaller for PRTG Network Monitor on Windows Server.

.DESCRIPTION
    Stops PRTG services, runs the official unins000.exe silently, removes
    residual files/registry keys and writes a log to %TEMP%\PRTG.

.PARAMETER KeepData
    If specified, preserves PRTG data (C:\ProgramData\Paessler).

.EXAMPLE
    PS> .\uninstall-prtg.ps1

.EXAMPLE
    PS> .\uninstall-prtg.ps1 -KeepData

.NOTES
    Author : dineshpandey3683
    Repo   : InstallPRTGNetworkMonitor
#>

[CmdletBinding()]
param(
    [switch]$KeepData
)

$ErrorActionPreference = "Stop"

$LogDir  = "$env:TEMP\PRTG"
$LogFile = Join-Path $LogDir "uninstall-prtg.log"
$PrtgRoot     = "C:\Program Files (x86)\PRTG Network Monitor"
$PrtgDataRoot = "C:\ProgramData\Paessler\PRTG Network Monitor"
$Services     = @("PRTGCoreService","PRTGProbeService")

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","OK")] [string]$Level = "INFO"
    )
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line  = "[{0}] [{1}] {2}" -f $stamp, $Level, $Message
    switch ($Level) {
        "ERROR" { Write-Host $line -ForegroundColor Red }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        "OK"    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line -ForegroundColor Cyan }
    }
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line
}

function Assert-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object System.Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Administrator privileges required."
    }
    Write-Log "Administrator privileges confirmed." "OK"
}

function Stop-PrtgServices {
    foreach ($s in $Services) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne "Stopped") {
                Write-Log "Stopping $s ..."
                try { Stop-Service -Name $s -Force -ErrorAction Stop } catch { Write-Log "Failed to stop $s : $($_.Exception.Message)" "WARN" }
            }
            try { Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
        } else {
            Write-Log "Service $s not found (already removed?)." "WARN"
        }
    }
}

function Find-Uninstaller {
    $candidates = @(
        (Join-Path $PrtgRoot "unins000.exe"),
        (Join-Path $PrtgRoot "unins001.exe")
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

    # Fallback: scan registry uninstall keys
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($rp in $regPaths) {
        if (-not (Test-Path $rp)) { continue }
        Get-ChildItem $rp | ForEach-Object {
            $p = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -match "PRTG Network Monitor" -and $p.UninstallString) {
                return ($p.UninstallString -replace '"','').Trim()
            }
        }
    }
    return $null
}

function Invoke-Uninstaller {
    $unins = Find-Uninstaller
    if (-not $unins) {
        Write-Log "Official uninstaller not found. Will clean up manually." "WARN"
        return
    }
    Write-Log "Running uninstaller: $unins"
    $p = Start-Process -FilePath $unins -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait -PassThru
    Write-Log "Uninstaller exit code: $($p.ExitCode)"
}

function Remove-Residuals {
    if (Test-Path $PrtgRoot) {
        Write-Log "Removing $PrtgRoot ..."
        try { Remove-Item -Path $PrtgRoot -Recurse -Force -ErrorAction Stop } catch { Write-Log "Could not remove $PrtgRoot : $($_.Exception.Message)" "WARN" }
    }

    if ($KeepData) {
        Write-Log "KeepData specified - preserving $PrtgDataRoot" "OK"
    } elseif (Test-Path $PrtgDataRoot) {
        Write-Log "Removing $PrtgDataRoot ..."
        try { Remove-Item -Path $PrtgDataRoot -Recurse -Force -ErrorAction Stop } catch { Write-Log "Could not remove $PrtgDataRoot : $($_.Exception.Message)" "WARN" }
    }

    # Cleanup leftover registry entries
    $regPaths = @(
        "HKLM:\SOFTWARE\Paessler",
        "HKLM:\SOFTWARE\WOW6432Node\Paessler"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            Write-Log "Removing registry $rp"
            try { Remove-Item -Path $rp -Recurse -Force -ErrorAction Stop } catch { Write-Log "Could not remove $rp : $($_.Exception.Message)" "WARN" }
        }
    }
}

try {
    Write-Log "=== PRTG Network Monitor Uninstaller started ===" "OK"
    Assert-Admin
    Stop-PrtgServices
    Invoke-Uninstaller
    Remove-Residuals
    Write-Log "=== Uninstall finished ===" "OK"
    Write-Log "Log file: $LogFile" "OK"
    exit 0
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    exit 1
}
