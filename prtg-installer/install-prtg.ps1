<#
.SYNOPSIS
    Silent installer for PRTG Network Monitor on Windows Server.

.DESCRIPTION
    Performs the following tasks:
      1. Verifies the script is running with Administrator privileges.
      2. Verifies the operating system is a supported Windows Server edition.
      3. Verifies .NET Framework 4.7.2 (or higher) is installed.
      4. Downloads the latest PRTG Network Monitor installer from Paessler.
      5. Runs the installer silently.
      6. Configures the PRTG Core Server to listen on HTTP port 8080.
      7. Starts PRTG services and writes a detailed log.

.PARAMETER InstallPath
    Destination folder for the downloaded installer.
    Defaults to "$env:TEMP\PRTG".

.PARAMETER WebPort
    HTTP port used by the PRTG web server. Defaults to 8080.

.PARAMETER LicenseName
    Name used for the PRTG freeware/trial license. Defaults to "PRTG Trial".

.PARAMETER LicenseKey
    License key. If omitted the installer uses the freeware/trial key embedded
    in the official download.

.EXAMPLE
    PS> .\install-prtg.ps1

.EXAMPLE
    PS> .\install-prtg.ps1 -WebPort 8081 -LicenseName "ACME" -LicenseKey "XXXXX-XXXXX-XXXXX"

.NOTES
    Author : dineshpandey3683
    Repo   : InstallPRTGNetworkMonitor
    Tested : Windows Server 2019 / 2022, PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [string]$InstallPath  = "$env:TEMP\PRTG",
    [int]   $WebPort      = 8080,
    [string]$LicenseName  = "PRTG Trial",
    [string]$LicenseKey   = ""
)

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$LogFile       = Join-Path $InstallPath "install-prtg.log"
$DownloadUrl   = "https://download.paessler.com/download/prtg-download.exe"
$InstallerFile = Join-Path $InstallPath "prtg-download.exe"
$PrtgRoot      = "C:\Program Files (x86)\PRTG Network Monitor"
$PrtgConfig    = Join-Path $PrtgRoot "PRTG Configuration.dat"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
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

    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $line
}

function Assert-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object System.Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "This script must be run as Administrator." "ERROR"
        throw "Administrator privileges required."
    }
    Write-Log "Administrator privileges confirmed." "OK"
}

function Assert-WindowsServer {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Log "Detected OS: $($os.Caption) ($($os.Version))"

    # ProductType: 1 = Workstation, 2 = Domain Controller, 3 = Server
    if ($os.ProductType -eq 1) {
        Write-Log "PRTG Network Monitor is designed to run on Windows Server. Desktop Windows detected." "WARN"
        Write-Log "Installation will continue but is unsupported by Paessler." "WARN"
    } else {
        Write-Log "Windows Server edition confirmed." "OK"
    }
}

function Assert-DotNet {
    $key = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
    if (-not (Test-Path $key)) {
        Write-Log ".NET Framework 4.x is not installed." "ERROR"
        throw ".NET Framework 4.7.2 or higher is required."
    }

    $release = (Get-ItemProperty -Path $key -Name Release -ErrorAction Stop).Release
    # 461808 = 4.7.2, 528040 = 4.8, 533320 = 4.8.1
    if ($release -lt 461808) {
        Write-Log ".NET Framework release $release is lower than 4.7.2 (461808)." "ERROR"
        throw ".NET Framework 4.7.2 or higher is required."
    }
    Write-Log ".NET Framework release $release detected (>= 4.7.2)." "OK"
}

function Test-PortAvailable {
    param([int]$Port)
    $inUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($inUse) {
        Write-Log "TCP port $Port is already in use by PID(s): $($inUse.OwningProcess -join ',')." "WARN"
        return $false
    }
    Write-Log "TCP port $Port is available." "OK"
    return $true
}

function Get-PrtgInstaller {
    Write-Log "Downloading PRTG installer from $DownloadUrl ..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerFile -UseBasicParsing
    } catch {
        Write-Log "Download failed: $($_.Exception.Message)" "ERROR"
        throw
    }

    if (-not (Test-Path $InstallerFile)) {
        throw "Installer not found after download."
    }
    $size = [math]::Round((Get-Item $InstallerFile).Length / 1MB, 2)
    Write-Log "Installer downloaded ($size MB) -> $InstallerFile" "OK"
}

function Install-Prtg {
    Write-Log "Starting silent PRTG installation. This can take several minutes ..."

    $args = @("/verysilent","/suppressmsgboxes","/norestart","/SP-")
    if ($LicenseKey) {
        $args += "/LICENSENAME=`"$LicenseName`""
        $args += "/LICENSEKEY=`"$LicenseKey`""
    }

    $p = Start-Process -FilePath $InstallerFile -ArgumentList $args -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Write-Log "Installer exited with code $($p.ExitCode)." "ERROR"
        throw "PRTG installation failed."
    }
    Write-Log "PRTG installer finished successfully." "OK"
}

function Set-PrtgWebPort {
    param([int]$Port)

    $svc = Get-Service -Name "PRTGCoreService" -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "PRTGCoreService not found; skipping port configuration." "WARN"
        return
    }

    if ($svc.Status -eq "Running") {
        Write-Log "Stopping PRTGCoreService to update configuration ..."
        Stop-Service -Name "PRTGCoreService" -Force
    }

    if (-not (Test-Path $PrtgConfig)) {
        Write-Log "Configuration file not found: $PrtgConfig" "WARN"
        Write-Log "Port change skipped. Adjust via PRTG web UI -> Setup -> System Administration -> User Interface." "WARN"
    } else {
        try {
            [xml]$cfg = Get-Content -Path $PrtgConfig -Encoding UTF8
            $node = $cfg.SelectSingleNode("//webserverport")
            if ($node) {
                Write-Log "Changing webserverport $($node.'#text') -> $Port"
                $node.'#text' = "$Port"
            } else {
                $new = $cfg.CreateElement("webserverport")
                $new.InnerText = "$Port"
                $cfg.DocumentElement.AppendChild($new) | Out-Null
                Write-Log "Added webserverport=$Port"
            }
            $cfg.Save($PrtgConfig)
            Write-Log "Configuration saved." "OK"
        } catch {
            Write-Log "Unable to edit configuration: $($_.Exception.Message)" "WARN"
        }
    }

    Write-Log "Starting PRTGCoreService ..."
    Start-Service -Name "PRTGCoreService"
    Start-Sleep -Seconds 5

    $probe = Get-Service -Name "PRTGProbeService" -ErrorAction SilentlyContinue
    if ($probe -and $probe.Status -ne "Running") {
        Start-Service -Name "PRTGProbeService"
    }
    Write-Log "PRTG services are running." "OK"
}

function Show-Summary {
    $host1 = [System.Net.Dns]::GetHostName()
    Write-Log "------------------------------------------------------------" "OK"
    Write-Log "PRTG Network Monitor installation complete." "OK"
    Write-Log "Web interface : http://$host1:$WebPort" "OK"
    Write-Log "Default login : prtgadmin / prtgadmin (change immediately!)" "OK"
    Write-Log "Install log   : $LogFile" "OK"
    Write-Log "------------------------------------------------------------" "OK"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
try {
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    Write-Log "=== PRTG Network Monitor Installer started ===" "OK"
    Write-Log "Parameters: InstallPath=$InstallPath, WebPort=$WebPort, LicenseName='$LicenseName'"

    Assert-Admin
    Assert-WindowsServer
    Assert-DotNet
    [void](Test-PortAvailable -Port $WebPort)

    Get-PrtgInstaller
    Install-Prtg
    Set-PrtgWebPort -Port $WebPort
    Show-Summary

    Write-Log "=== Finished successfully ===" "OK"
    exit 0
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    Write-Log "Installation aborted." "ERROR"
    exit 1
}
