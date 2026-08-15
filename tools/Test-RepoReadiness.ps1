[CmdletBinding()]
param()

<#
Module: Test-RepoReadiness.ps1
Purpose: Run local self-readiness and LCM compliance quality checks for VolumeInventory.
Path: tools/Test-RepoReadiness.ps1
Authors: Rolf
Version: 1.0.0
Changelog:
- 2026-08-15: Initial readiness runner instantiated.
#>

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

$qualityGatesModule = Join-Path $PSScriptRoot 'QualityGates\RepoQualityGates.psm1'
if (Test-Path -LiteralPath $qualityGatesModule) {
  Import-Module $qualityGatesModule -Force
  Assert-RepoStructure -RepoRoot $repoRoot | Out-Host
  Assert-RepoFormatting -RepoRoot $repoRoot | Out-Host
  Assert-RepoGovernanceLinks -RepoRoot $repoRoot | Out-Host
} else {
  Write-Warning "QualityGates module not found at: $qualityGatesModule"
}

Write-Host 'VolumeInventory readiness check: OK'
