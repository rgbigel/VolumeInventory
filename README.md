# VolumeInventory

Version: 2.5.0

Windows volume inventory utility written in PowerShell, with documented commands run through `pwsh`, by combining:

- fltmc volumes
- Get-Partition
- bcdedit /enum all /v

It resolves partition metadata for lettered and unlettered volumes (including recovery volumes), marks BCD-referenced volumes, and can export results to CSV.

## Repository Layout

- src/VolumeInventory.ps1: Main script
- scripts/Install-VolumeInventory.ps1: Installer to copy main script into cmd folder
- tests/VolumeInventory.Tests.ps1: Basic parser and contract checks
- docs/CHANGELOG.md: Project changelog
- .github/workflows/ci.yml: GitHub Actions CI

## System Prerequisites

- **Operating System**: Windows 10/11 x64
- **PowerShell**: PowerShell 7 (`pwsh.exe` 7.0+)
- **Git**: Git for Windows
- **Filesystem**: NTFS filesystem (directory junctions & hardlinks)
- **Privileges**: Administrator privileges required for low-level storage query APIs (`bcdedit`, `fltmc`, `Get-Partition`)

## Usage

Run default table output:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\src\VolumeInventory.ps1
```

Include shadow copy volumes:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\src\VolumeInventory.ps1 -IncludeShadowCopy
```

Show only BCD-referenced volumes:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\src\VolumeInventory.ps1 -OnlyBcdReferenced
```

Export to CSV:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\src\VolumeInventory.ps1 -ExportCsvPath .\out\volumes.csv
```

Return objects for piping:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\src\VolumeInventory.ps1 -PassThru
```

Install script into D:\OneDrive\cmd:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-VolumeInventory.ps1
```

Install script into a custom cmd folder:

```pwsh
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-VolumeInventory.ps1 -TargetCmdDir D:\Custom\cmd
```

## Development

Parser check:

```pwsh
pwsh -NoProfile -Command "$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('.\\src\\VolumeInventory.ps1', [ref]$null, [ref]$errors) | Out-Null; if ($errors) { $errors | ForEach-Object { $_.Message }; exit 1 }"
```

Pester tests:

```pwsh
pwsh -NoProfile -Command "Invoke-Pester -Path .\\tests"
```

## Notes

- Shadow copy rows are excluded by default.
- Mapping is serial-based; this enables metadata for unlettered partitions.
- Non-volume pseudo devices (`Mailslot`, `Mup`, `NamedPipe`) are filtered out from fltmc output.
- Installer aborts if additional source scripts or module dependency declarations are detected.
- BCD is displayed as `T` for referenced rows and blank otherwise.
- Output includes `VolumeLabel` where available.
- When filesystem cannot be read directly, Linux partition GPT types are shown as `LinuxFS` or `LinuxSwap` where detectable.
- Linux GPT partitions without NT volume objects are included as synthetic rows (`DiskX-PartY`).
- Default table headings are compact: `Drive`, `Device\`, `Disk #`, `Part.#`.
- Device values are rendered as `Vol N` for `\Device\HarddiskVolumeN`.
- Synthetic device values are compacted:
	- `DiskX-PartY` -> `DX-PY`
	- `DiskX-Unallocated` -> `DX-UnAl`
- Size is shown as `MB` (integer) or `GB` (2 decimals with decimal point).
- Synthetic unallocated rows are included with `Part.#` shown as `-`.
- Final ordering follows physical disk sequence by start offset, so allocated partitions and synthetic unallocated ranges are interleaved as they appear on disk.
- `Role` highlights recognizable categories (`Reco`, `EFI`, `LinuxFS`, `LinuxSwap`).
