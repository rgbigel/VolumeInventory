# Changelog

## 1.3.0 - 2026-05-27

- Added `Role` column (`Reco`, `EFI`, `LinuxFS`, `LinuxSwap`).
- Changed default headings to compact names: `Drive`, `Device\\`, `Disk #`, `Partition #`.
- Default table shortens device values by removing `\\Device\\` prefix.

## 1.2.0 - 2026-05-27

- Changed `InBCD` output to `T` (true) or blank (false).
- Added `VolumeLabel` output column.
- Removed `IsRecovery` output column.
- Added deterministic Linux filesystem hints from GPT types:
	- `LinuxFS` for `{0fc63daf-8483-4772-8e79-3d69d8477de4}`
	- `LinuxSwap` for `{0657fd6d-a4ab-43c4-84e5-0933c84b4f4f}`
- Fixed `VolumeLabel` parsing for blank-label rows.
- Added synthetic rows for Linux GPT partitions that have no NT volume object (`DiskX-PartY`).

## 1.1.0 - 2026-05-27

- Added scripts/Install-Get-VolumeInventory.ps1.
- Installer copies src/Get-VolumeInventory.ps1 to D:\OneDrive\cmd by default.
- Installer now aborts if source-script count is not exactly one or if module dependency declarations are detected.
- Updated README with installer usage.

## 1.0.0 - 2026-05-27

- Initial repository scaffold.
- Added src/Get-VolumeInventory.ps1.
- Added tests/Get-VolumeInventory.Tests.ps1.
- Added GitHub Actions CI workflow.
- Added README and project metadata files.
