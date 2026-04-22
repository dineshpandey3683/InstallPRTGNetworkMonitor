# InstallPRTGNetworkMonitor

Automated, silent installation of **PRTG Network Monitor** on Windows Server using PowerShell.

The scripts in this repository perform prerequisite checks, download the latest PRTG installer directly from Paessler, install it unattended, configure the web server port, and provide a matching clean uninstaller.

---

## Contents

| File                     | Purpose                                                        |
| ------------------------ | -------------------------------------------------------------- |
| `install-prtg.ps1`       | Silent installer with prerequisite checks and port configuration |
| `uninstall-prtg.ps1`     | Clean uninstaller (services, program files, data, registry)    |
| `.gitignore`             | Excludes logs, installers, screenshots and temporary files     |
| `README.md`              | This document                                                  |

---

## Prerequisites

- **Operating system:** Windows Server 2016 / 2019 / 2022 (Windows 10/11 will also work but is unsupported by Paessler).
- **Privileges:** A local account that is a member of the **Administrators** group.
- **.NET Framework:** 4.7.2 or higher (the installer checks this automatically).
- **PowerShell:** 5.1 or later (included with all supported Windows Server editions).
- **Network:** Outbound HTTPS access to `download.paessler.com`.
- **Disk space:** At least **1 GB** free on the system drive.
- **Ports:** TCP **8080** free (or a custom port of your choice).

---

## Quick start

1. Clone or download this repository onto the target Windows Server.

   ```powershell
   git clone https://github.com/dineshpandey3683/InstallPRTGNetworkMonitor.git
   cd InstallPRTGNetworkMonitor
   ```

2. Open **PowerShell as Administrator**.

3. Allow the script to run for the current session (only needed once):

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   ```

4. Run the installer:

   ```powershell
   .\install-prtg.ps1
   ```

5. When the script finishes, open the URL printed at the end, e.g.

   ```
   http://<your-server>:8080
   ```

   Default credentials are `prtgadmin` / `prtgadmin`. **Change them immediately.**

---

## Usage

### Install with defaults

```powershell
.\install-prtg.ps1
```

### Install on a custom port

```powershell
.\install-prtg.ps1 -WebPort 8081
```

### Install with a commercial license

```powershell
.\install-prtg.ps1 -LicenseName "ACME Corp" -LicenseKey "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
```

### Parameters

| Parameter      | Default                 | Description                                          |
| -------------- | ----------------------- | ---------------------------------------------------- |
| `-InstallPath` | `$env:TEMP\PRTG`        | Folder used to cache the downloaded installer and log |
| `-WebPort`     | `8080`                  | HTTP port for the PRTG web interface                 |
| `-LicenseName` | `"PRTG Trial"`          | License name (ignored when `-LicenseKey` is empty)   |
| `-LicenseKey`  | *(empty = trial/freeware)* | License key issued by Paessler                       |

---

## Uninstall

```powershell
.\uninstall-prtg.ps1
```

Preserve PRTG data (historical monitoring database) while removing the program:

```powershell
.\uninstall-prtg.ps1 -KeepData
```

The uninstaller:

1. Stops `PRTGCoreService` and `PRTGProbeService`.
2. Runs the official `unins000.exe` silently.
3. Removes leftover program files, `ProgramData` folder and `HKLM\SOFTWARE\Paessler` registry entries.
4. Writes a log to `%TEMP%\PRTG\uninstall-prtg.log`.

---

## Logs

Both scripts write a detailed log to:

```
%TEMP%\PRTG\install-prtg.log
%TEMP%\PRTG\uninstall-prtg.log
```

Attach these logs when reporting issues.

---

## Troubleshooting

| Symptom                                                       | Likely cause / fix                                                                                                      |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `Administrator privileges required.`                          | Re-open PowerShell with **Run as Administrator**.                                                                       |
| `.NET Framework 4.7.2 or higher is required.`                 | Install .NET 4.8 from Microsoft and reboot.                                                                             |
| Script blocked: *running scripts is disabled on this system.* | Run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` in the same PowerShell session.                  |
| Download fails / timeout.                                     | Verify outbound HTTPS access to `download.paessler.com`. Behind a proxy set `$env:HTTPS_PROXY` before running.           |
| `TCP port 8080 is already in use`                             | Pick another port: `.\install-prtg.ps1 -WebPort 8081` or free the port by stopping the conflicting service.             |
| Web UI not reachable after install.                           | Check Windows Firewall inbound rules; make sure `PRTGCoreService` is running (`Get-Service PRTG*`).                     |
| Installer exits with non-zero code.                           | Review `%TEMP%\PRTG\install-prtg.log` and the installer's own log under `C:\ProgramData\Paessler\PRTG Network Monitor\`. |

---

## Security notes

- Default credentials (`prtgadmin`/`prtgadmin`) **must** be changed on first login.
- For production use, switch the web interface to HTTPS (PRTG Web Server setup) and restrict access via firewall rules.
- Keep PRTG updated — the Paessler auto-update feature can be enabled from the web UI.

---

## License

This repository is released under the MIT License. PRTG Network Monitor itself is a commercial product from **Paessler AG** and is subject to its own [EULA](https://www.paessler.com/company/terms).
