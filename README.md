# Get-VolumeInventory

Windows PowerShell utility to build a unified volume inventory by combining:

- fltmc volumes
- Get-Partition
- bcdedit /enum all /v

It resolves partition metadata for lettered and unlettered volumes (including recovery volumes), marks BCD-referenced volumes, and can export results to CSV.

## Repository Layout

- src/Get-VolumeInventory.ps1: Main script
- tests/Get-VolumeInventory.Tests.ps1: Basic parser and contract checks
- docs/CHANGELOG.md: Project changelog
- .github/workflows/ci.yml: GitHub Actions CI

## Requirements

- Windows
- PowerShell 5.1 or PowerShell 7+
- Administrative shell recommended (for complete device visibility)

## Usage

Run default table output:

powershell -ExecutionPolicy Bypass -File .\src\Get-VolumeInventory.ps1

Include shadow copy volumes:

powershell -ExecutionPolicy Bypass -File .\src\Get-VolumeInventory.ps1 -IncludeShadowCopy

Show only BCD-referenced volumes:

powershell -ExecutionPolicy Bypass -File .\src\Get-VolumeInventory.ps1 -OnlyBcdReferenced

Export to CSV:

powershell -ExecutionPolicy Bypass -File .\src\Get-VolumeInventory.ps1 -ExportCsvPath .\out\volumes.csv

Return objects for piping:

powershell -ExecutionPolicy Bypass -File .\src\Get-VolumeInventory.ps1 -PassThru

## Development

Parser check:

powershell -NoProfile -Command "$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('.\\src\\Get-VolumeInventory.ps1', [ref]$null, [ref]$errors) | Out-Null; if ($errors) { $errors | ForEach-Object { $_.Message }; exit 1 }"

Pester tests:

powershell -NoProfile -Command "Invoke-Pester -Path .\\tests -Output Detailed"

## Notes

- Shadow copy rows are excluded by default.
- Mapping is serial-based; this enables metadata for unlettered partitions.
- Non-volume pseudo devices (for example Mup, NamedPipe) can appear in fltmc output.
