# File:       Install-VolumeInventory.ps1
# Version:    2.0.0
# Author:     Rolf
# Created:    2026-05-27
# Updated:    2026-05-29
# Purpose:
#   Installs VolumeInventory.ps1 into a target cmd directory.
#
#   Safety rule requested for project bootstrap:
#   - Assume exactly one distributable source script (VolumeInventory.ps1).
#   - Abort if additional source scripts are present or if module dependencies
#     are declared in the main script.
# Parameters:
#   -TargetCmdDir <path>   Optional. Destination directory.
#                          Default: D:\OneDrive\cmd
# Outputs:
#   Copies src\VolumeInventory.ps1 to <TargetCmdDir>\VolumeInventory.ps1.
# Changelog:
#   2.0.0 - Renamed installer and source target to VolumeInventory naming.

[CmdletBinding()]
param(
    [string]$TargetCmdDir = "D:\OneDrive\cmd",
    [Alias("h","?")]
    [switch]$HelpMode
)

if ($HelpMode) {
    Get-Help $PSCommandPath -Full
    exit 0
}

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$srcDir = Join-Path $repoRoot "src"

if (-not (Test-Path -LiteralPath $srcDir)) {
    throw "Source directory not found: $srcDir"
}

$srcScripts = Get-ChildItem -LiteralPath $srcDir -File -Filter "*.ps1"

if ($srcScripts.Count -ne 1) {
    throw "Install aborted: expected exactly one source .ps1 in '$srcDir', found $($srcScripts.Count)."
}

$mainScript = $srcScripts | Where-Object { $_.Name -ieq "VolumeInventory.ps1" } | Select-Object -First 1
if (-not $mainScript) {
    throw "Install aborted: expected source script 'VolumeInventory.ps1' in '$srcDir'."
}

$scriptText = Get-Content -LiteralPath $mainScript.FullName -Raw
$hasModuleDependency =
    ($scriptText -match '(?im)^\s*Import-Module\b') -or
    ($scriptText -match '(?im)^\s*#requires\s+-Modules\b') -or
    ($scriptText -match '(?im)^\s*using\s+module\b')

if ($hasModuleDependency) {
    throw "Install aborted: module dependency declaration detected in '$($mainScript.Name)'."
}

if (-not (Test-Path -LiteralPath $TargetCmdDir)) {
    New-Item -ItemType Directory -Path $TargetCmdDir -Force | Out-Null
}

$destination = Join-Path $TargetCmdDir $mainScript.Name
Copy-Item -LiteralPath $mainScript.FullName -Destination $destination -Force

Write-Host "Installed: $destination" -ForegroundColor Green
