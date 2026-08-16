[CmdletBinding()]
param(
    [switch]$IncludeShadowCopy,
    [switch]$OnlyBcdReferenced,
    [switch]$PassThru,
    [string]$ExportCsvPath,
    [Alias("h","?")]
    [switch]$HelpMode
)

# File:       VolumeInventory.ps1
# Version:    2.5.0
# Author:     Rolf
# Created:    2026-05-27
# Updated:    2026-08-13
# Purpose:
#   Builds a unified volume inventory by combining:
#   - fltmc volumes (NT device names like \Device\HarddiskVolumeN)
#   - Get-Partition (partition type, GPT/MBR type, disk/partition number)
#   - bcdedit /enum all /v (flag whether the volume is referenced by BCD)
#
#   This works for lettered and unlettered volumes, including recovery volumes,
#   by joining through volume serial numbers.
# Parameters:
#   -IncludeShadowCopy     Optional switch. If omitted, shadow copy rows are excluded.
#   -OnlyBcdReferenced     Optional switch. If set, only rows referenced by BCD are shown.
#   -PassThru              Optional switch. If set, returns objects instead of table output.
#   -ExportCsvPath <path>  Optional. If specified, exports the final result to CSV.
# Outputs:
#   Default: formatted table to host.
#   PassThru: array of PSCustomObject with columns:
#             InBCD, DosName, VolumeName, VolumeLabel, FileSystem, SizeBytes,
#             PartitionType, GptType, MbrType, DiskNumber, PartitionNumber, Role.
# Changelog:
#   2.5.0 - Marked method-clean release pending test and aligned helper function
#           structure with Workspace_GC PowerShell lifecycle methodology.
#   2.0.2 - Final ordering now follows physical disk sequence by start offset,
#           so allocated partitions and synthetic unallocated ranges are interleaved
#           exactly as they appear on disk.
#   2.0.1 - Device\ values now abbreviate synthetic names:
#           DiskX-PartY -> DX-PY, DiskX-Unallocated -> DX-UnAl.
#           Excludes non-volume pseudo devices: Mailslot, Mup, NamedPipe.
#   2.0.0 - Renamed script/repository naming to VolumeInventory.
#           Renamed output headings: BCD, Type, Part.#, Size.
#           Device values now show Vol N instead of HarddiskVolumeN.
#           Default sort changed to Disk # then Part.#.
#           Added synthetic unallocated rows with Part.# shown as '-'.
#           Size column now renders as MB (integer) or GB (2 decimals).
#   1.3.0 - Added Role column (Reco/EFI/LinuxFS/LinuxSwap).
#           Compact default table headings: Drive, Device\, Disk #, Partition #.
#           Default table now shortens device values by dropping '\Device\' prefix.
#   1.2.0 - InBCD display normalized to "T" or blank.
#           Added VolumeLabel output column.
#           Removed IsRecovery output column.
#           Added deterministic LinuxFS/LinuxSwap filesystem hints from partition GPT type.
#   1.0.0 - Initial version.

<#
.SYNOPSIS
    Builds a unified inventory of Windows volumes and partition metadata.

.DESCRIPTION
    Correlates fltmc, partition, and BCD data to present consolidated volume
    rows and optional CSV output.

.PARAMETER HelpMode
    Shows full help and exits.
    Aliases: h, ?
#>

if ($HelpMode) {
    Get-Help $PSCommandPath -Full
    exit 0
}

$ErrorActionPreference = "Stop"

function Get-VolumeSerialHex {
    [CmdletBinding()]
    param([string]$Path)

    try {
        $text = fsutil fsinfo volumeinfo $Path 2>$null | Out-String
        if ($text -match '(?im)^\s*Volume Serial Number\s*:\s*0x([0-9a-f]+)\s*$') {
            return $matches[1].ToLower()
        }
    }
    catch {
    }

    return $null
}

function Get-VolumeFsInfo {
    [CmdletBinding()]
    param([string]$Path)

    $result = [PSCustomObject]@{
        SerialHex      = $null
        VolumeLabel    = $null
        FileSystemName = $null
    }

    try {
        $text = fsutil fsinfo volumeinfo $Path 2>$null | Out-String
        if ($text -match '(?im)^\s*Volume Serial Number\s*:\s*0x([0-9a-f]+)\s*$') {
            $result.SerialHex = $matches[1].ToLower()
        }

        if ($text -match '(?im)^[ \t]*Volume Name[ \t]*:[ \t]*(.*)$') {
            $label = $matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($label)) {
                $result.VolumeLabel = $label
            }
        }

        if ($text -match '(?im)^[ \t]*File System Name[ \t]*:[ \t]*(.*)$') {
            $fsName = $matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($fsName)) {
                $result.FileSystemName = $fsName
            }
        }
    }
    catch {
    }

    return $result
}

function Get-BcdReferencedNtVolumes {
    [CmdletBinding()]
    param()

    $bcdEdit = Join-Path $env:WINDIR "System32\bcdedit.exe"
    $all = & $bcdEdit /enum all /v 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "bcdedit /enum all /v failed or requires administrator privileges. Continuing without BCD reference flags."
        return @()
    }

    $volumes = $all -split "`r?`n" |
        Where-Object { $_ -match '^\s*(device|osdevice)\s+partition=\\Device\\HarddiskVolume\d+' } |
        ForEach-Object {
            if ($_ -match 'partition=(\\Device\\HarddiskVolume\d+)') {
                $matches[1]
            }
        } |
        Sort-Object -Unique

    return @($volumes)
}

function Get-PartitionMetaBySerial {
    [CmdletBinding()]
    param()

    $map = @{}

    Get-Partition | ForEach-Object {
        $partition = $_
        $accessPaths = @($partition.AccessPaths | Where-Object { $_ -match '^\\\\\?\\Volume\{[^}]+\}\\$' })

        foreach ($accessPath in $accessPaths) {
            $serial = Get-VolumeSerialHex -Path $accessPath
            if (-not $serial) { continue }

            if (-not $map.ContainsKey($serial)) {
                $map[$serial] = [PSCustomObject]@{
                    PartitionType   = $partition.Type
                    GptType         = $partition.GptType
                    MbrType         = $partition.MbrType
                    DiskNumber      = $partition.DiskNumber
                    PartitionNumber = $partition.PartitionNumber
                    StartOffset     = [int64]$partition.Offset
                    SizeBytes       = $partition.Size
                }
            }
        }
    }

    return $map
}

function Get-FltmcVolumeRows {
    [CmdletBinding()]
    param()

    $rows = fltmc volumes |
        Select-Object -Skip 2 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            if ($_ -match '^\s*(?<dos>[A-Z]:)?\s*(?<vol>\\Device\\[^\s]+)\s+(?<fs>\S+)\s*(?<status>\S+)?\s*$') {
                $volumeName = $matches['vol']
                if ($volumeName -match '^\\Device\\(Mailslot|Mup|NamedPipe)(\\|$)') {
                    return
                }

                [PSCustomObject]@{
                    DosName    = $matches['dos']
                    VolumeName = $volumeName
                    FileSystem = $matches['fs']
                }
            }
        }

    return @($rows)
}

function Format-SizeText {
    [CmdletBinding()]
    param([Nullable[Int64]]$SizeBytes)

    if ($null -eq $SizeBytes -or $SizeBytes -le 0) {
        return ""
    }

    if ($SizeBytes -lt 1GB) {
        $mb = [Math]::Round(($SizeBytes / 1MB), 0)
        return ("{0} MB" -f [int64]$mb)
    }

    return ("{0:N2} GB" -f ($SizeBytes / 1GB))
}

function Get-UnallocatedRows {
    [CmdletBinding()]
    param()

    $rows = @()
    $disks = @(Get-Disk)
    if (-not $disks -or $disks.Count -eq 0) {
        return $rows
    }

    $allPartitions = @(Get-Partition)
    foreach ($disk in $disks) {
        $diskNumber = $disk.Number
        $diskSize = [int64]$disk.Size
        $partitions = @(
            $allPartitions |
                Where-Object { $_.DiskNumber -eq $diskNumber } |
                Sort-Object -Property Offset
        )

        $cursor = [int64]0
        foreach ($partition in $partitions) {
            $start = [int64]$partition.Offset
            $partSize = [int64]$partition.Size
            if ($start -gt $cursor) {
                $gap = $start - $cursor
                if ($gap -gt 0) {
                    $rows += [PSCustomObject]@{
                        InBCD           = ""
                        DosName         = $null
                        VolumeName      = "Disk$diskNumber-Unallocated"
                        VolumeLabel     = $null
                        FileSystem      = ""
                        StartOffset     = $cursor
                        SizeBytes       = $gap
                        PartitionType   = "Unallocated"
                        GptType         = $null
                        MbrType         = $null
                        DiskNumber      = $diskNumber
                        PartitionNumber = $null
                        Role            = "Unalloc"
                    }
                }
            }

            $end = $start + $partSize
            if ($end -gt $cursor) {
                $cursor = $end
            }
        }

        if ($diskSize -gt $cursor) {
            $tail = $diskSize - $cursor
            if ($tail -gt 0) {
                $rows += [PSCustomObject]@{
                    InBCD           = ""
                    DosName         = $null
                    VolumeName      = "Disk$diskNumber-Unallocated"
                    VolumeLabel     = $null
                    FileSystem      = ""
                    StartOffset     = $cursor
                    SizeBytes       = $tail
                    PartitionType   = "Unallocated"
                    GptType         = $null
                    MbrType         = $null
                    DiskNumber      = $diskNumber
                    PartitionNumber = $null
                    Role            = "Unalloc"
                }
            }
        }
    }

    return $rows
}

$linuxFsGptType = '{0fc63daf-8483-4772-8e79-3d69d8477de4}'
$linuxSwapGptType = '{0657fd6d-a4ab-43c4-84e5-0933c84b4f4f}'
$efiSystemGptType = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
$recoveryGptType = '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
$bcdVolumes = Get-BcdReferencedNtVolumes
$partitionMetaBySerial = Get-PartitionMetaBySerial
$fltmcRows = Get-FltmcVolumeRows

if (-not $IncludeShadowCopy) {
    $fltmcRows = @($fltmcRows | Where-Object { $_.VolumeName -notmatch '^\\Device\\HarddiskVolumeShadowCopy\d+$' })
}

$result = @(foreach ($row in $fltmcRows) {
    $sizeBytes = $null
    if ($row.DosName) {
        $drive = $row.DosName.TrimEnd(':')
        try {
            $volume = Get-Volume -DriveLetter $drive -ErrorAction Stop
            if ($volume.Size) {
                $sizeBytes = [int64]$volume.Size
            }
        }
        catch {
        }
    }

    $globalRootPath = "\\?\GLOBALROOT$($row.VolumeName)"
    $fsInfo = Get-VolumeFsInfo -Path $globalRootPath
    $serial = $fsInfo.SerialHex
    $volumeLabel = $fsInfo.VolumeLabel

    $meta = $null
    if ($serial -and $partitionMetaBySerial.ContainsKey($serial)) {
        $meta = $partitionMetaBySerial[$serial]
    }

    $partitionType = if ($meta) { $meta.PartitionType } else { $null }
    $gptType = if ($meta) { $meta.GptType } else { $null }
    $mbrType = if ($meta) { $meta.MbrType } else { $null }
    $diskNumber = if ($meta) { $meta.DiskNumber } else { $null }
    $partitionNumber = if ($meta) { $meta.PartitionNumber } else { $null }
    $startOffset = if ($meta) { $meta.StartOffset } else { $null }
    if ($null -eq $sizeBytes -and $meta -and $meta.SizeBytes) {
        $sizeBytes = [int64]$meta.SizeBytes
    }

    $fileSystem = $row.FileSystem
    if ([string]::IsNullOrWhiteSpace($fileSystem) -and -not [string]::IsNullOrWhiteSpace($fsInfo.FileSystemName)) {
        $fileSystem = $fsInfo.FileSystemName
    }

    if ([string]::IsNullOrWhiteSpace($fileSystem) -and $gptType) {
        $gptLower = $gptType.ToString().ToLower()
        if ($gptLower -eq $linuxFsGptType) {
            $fileSystem = "LinuxFS"
        }
        elseif ($gptLower -eq $linuxSwapGptType) {
            $fileSystem = "LinuxSwap"
        }
    }

    $inBcdMarker = if ($bcdVolumes -contains $row.VolumeName) { "T" } else { "" }

    $role = ""
    $gptLower = if ($gptType) { $gptType.ToString().ToLower() } else { "" }
    if ($partitionType -eq 'Recovery' -or $gptLower -eq $recoveryGptType -or $mbrType -eq 39) {
        $role = "Reco"
    }
    elseif ($partitionType -eq 'System' -or $gptLower -eq $efiSystemGptType) {
        $role = "EFI"
    }
    elseif ($gptLower -eq $linuxSwapGptType -or $fileSystem -eq 'LinuxSwap') {
        $role = "LinuxSwap"
    }
    elseif ($gptLower -eq $linuxFsGptType -or $fileSystem -eq 'LinuxFS') {
        $role = "LinuxFS"
    }

    [PSCustomObject]@{
        InBCD           = $inBcdMarker
        DosName         = $row.DosName
        VolumeName      = $row.VolumeName
        VolumeLabel     = $volumeLabel
        FileSystem      = $fileSystem
        StartOffset     = $startOffset
        SizeBytes       = $sizeBytes
        PartitionType   = $partitionType
        GptType         = $gptType
        MbrType         = $mbrType
        DiskNumber      = $diskNumber
        PartitionNumber = $partitionNumber
        Role            = $role
    }
})

$existingDiskPartKeys = @{}
foreach ($row in $result) {
    if ($null -ne $row.DiskNumber -and $null -ne $row.PartitionNumber) {
        $existingDiskPartKeys["$($row.DiskNumber):$($row.PartitionNumber)"] = $true
    }
}

$linuxPartitions = Get-Partition | Where-Object {
    $_.GptType -and @($linuxFsGptType, $linuxSwapGptType) -contains $_.GptType.ToString().ToLower()
}

foreach ($partition in $linuxPartitions) {
    $key = "$($partition.DiskNumber):$($partition.PartitionNumber)"
    if ($existingDiskPartKeys.ContainsKey($key)) { continue }

    $linuxFsHint = if ($partition.GptType.ToString().ToLower() -eq $linuxSwapGptType) { "LinuxSwap" } else { "LinuxFS" }
    $sizeBytes = $null
    if ($partition.Size) {
        $sizeBytes = [int64]$partition.Size
    }

    $result += [PSCustomObject]@{
        InBCD           = ""
        DosName         = $null
        VolumeName      = "Disk$($partition.DiskNumber)-Part$($partition.PartitionNumber)"
        VolumeLabel     = $null
        FileSystem      = $linuxFsHint
        StartOffset     = [int64]$partition.Offset
        SizeBytes       = $sizeBytes
        PartitionType   = $partition.Type
        GptType         = $partition.GptType
        MbrType         = $partition.MbrType
        DiskNumber      = $partition.DiskNumber
        PartitionNumber = $partition.PartitionNumber
        Role            = $linuxFsHint
    }
}

$unallocatedRows = Get-UnallocatedRows
if ($unallocatedRows -and $unallocatedRows.Count -gt 0) {
    $result += $unallocatedRows
}

if ($OnlyBcdReferenced) {
    $result = @($result | Where-Object { $_.InBCD -eq "T" })
}

if (-not [string]::IsNullOrWhiteSpace($ExportCsvPath)) {
    $result | Export-Csv -Path $ExportCsvPath -NoTypeInformation -Encoding UTF8
}

$sortedResult = @(
    $result |
        Sort-Object -Property @(
            @{ Expression = { if ($null -eq $_.DiskNumber) { [int]::MaxValue } else { [int]$_.DiskNumber } }; Descending = $false },
            @{ Expression = { if ($null -eq $_.StartOffset) { [int64]::MaxValue } else { [int64]$_.StartOffset } }; Descending = $false },
            @{ Expression = { if ($null -eq $_.PartitionNumber) { [int]::MaxValue } else { [int]$_.PartitionNumber } }; Descending = $false },
            @{ Expression = { $_.VolumeName }; Descending = $false }
        )
)

if ($PassThru) {
    return @(
        $sortedResult |
            Select-Object -Property @(
                'InBCD',
                'DosName',
                'VolumeName',
                'VolumeLabel',
                'FileSystem',
                'StartOffset',
                'SizeBytes',
                'PartitionType',
                'GptType',
                'MbrType',
                'DiskNumber',
                'PartitionNumber',
                'Role'
            )
    )
}

$sortedResult |
    Select-Object -Property @(
        @{ Name = 'BCD'; Expression = { $_.InBCD } },
        @{ Name = 'Drive'; Expression = { $_.DosName } },
        @{ Name = 'Device\'; Expression = {
            if ([string]::IsNullOrWhiteSpace($_.VolumeName)) { return $_.VolumeName }
            if ($_.VolumeName -match '^\\Device\\HarddiskVolume(\d+)$') {
                return ("Vol {0}" -f $matches[1])
            }
            if ($_.VolumeName -match '^Disk(\d+)-Part(\d+)$') {
                return ("D{0}-P{1}" -f $matches[1], $matches[2])
            }
            if ($_.VolumeName -match '^Disk(\d+)-Unallocated$') {
                return ("D{0}-UnAl" -f $matches[1])
            }
            return ($_.VolumeName -replace '^\\Device\\', '')
        } },
        @{ Name = 'VolumeLabel'; Expression = { $_.VolumeLabel } },
        @{ Name = 'FileSystem'; Expression = { $_.FileSystem } },
        @{ Name = 'Size'; Expression = { Format-SizeText -SizeBytes $_.SizeBytes } },
        @{ Name = 'Role'; Expression = { $_.Role } },
        @{ Name = 'Type'; Expression = { $_.PartitionType } },
        @{ Name = 'Disk #'; Expression = { $_.DiskNumber } },
        @{ Name = 'Part.#'; Expression = { if ($null -eq $_.PartitionNumber) { '-' } else { $_.PartitionNumber } } }
    ) |
    Format-Table -AutoSize
