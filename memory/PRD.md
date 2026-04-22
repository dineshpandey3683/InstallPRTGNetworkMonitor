# PRD — InstallPRTGNetworkMonitor

## Original problem statement
User wants to publish a set of working files to their connected GitHub repo `dineshpandey3683/InstallPRTGNetworkMonitor`, which currently only contains screenshots. Goal: turn it into a real, useful repository.

## User-confirmed scope (Jan 2026)
1. `install-prtg.ps1` — PowerShell silent installer for PRTG Network Monitor on Windows Server. Checks admin rights, .NET Framework, downloads latest PRTG, configures web port 8080.
2. `README.md` — Quick start, prerequisites, usage, troubleshooting.
3. `.gitignore` — Excludes screenshots, logs, installer binaries, temp files.
4. `uninstall-prtg.ps1` — Clean removal of services, program files, data, registry keys.

Target platform: Windows Server only (native PRTG platform).
Version: latest stable (always pulled from Paessler).

## Architecture
- No backend/frontend. Pure PowerShell scripting project.
- Files live at repo root:
  - `install-prtg.ps1`
  - `uninstall-prtg.ps1`
  - `README.md`
  - `.gitignore`

## Implemented (2026-01)
- [x] install-prtg.ps1 with admin / OS / .NET / port checks, download via `Invoke-WebRequest`, silent install flags, webserverport XML edit, service start, full logging to `%TEMP%\PRTG\install-prtg.log`.
- [x] uninstall-prtg.ps1 with service stop, registry fallback to locate `unins000.exe`, cleanup of `ProgramData\Paessler` and `HKLM\SOFTWARE\Paessler`, `-KeepData` switch.
- [x] README.md with quick start, parameter table, troubleshooting matrix, security notes.
- [x] .gitignore covering screenshots, installers, logs, editor and secret files.

## Validation
- Static review only. PowerShell scripts cannot be executed in this Linux container; logic was reviewed against Paessler silent-install documentation and Inno Setup switches used by the PRTG installer.
- User should run on a Windows Server VM to validate end-to-end.

## Backlog / next items
- P1: Add GitHub Actions workflow with PSScriptAnalyzer lint.
- P2: Optional HTTPS post-install configuration (generate self-signed cert, switch PRTG to SSL port 443).
- P2: Pester tests for helper functions (mock-friendly refactor).
- P3: Add a `configure-prtg.ps1` companion for post-install device/sensor seeding via the PRTG HTTP API.
