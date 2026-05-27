# File:       Get-VolumeInventory.ps1
# Version:    1.0.0
# Author:     Rolf
# Created:    2026-05-27
# Updated:    2026-05-27
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
#             InBCD, DosName, VolumeName, FileSystem, SizeGB, PartitionType,
#             GptType, MbrType, DiskNumber, PartitionNumber, IsRecovery.
# Changelog:
#   1.0.0 - Initial version.

param(
    [switch]$IncludeShadowCopy,
    [switch]$OnlyBcdReferenced,
    [switch]$PassThru,
    [string]$ExportCsvPath
)

$ErrorActionPreference = "Stop"

function Get-VolumeSerialHex {
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

function Get-BcdReferencedNtVolumes {
    $bcdEdit = Join-Path $env:WINDIR "System32\bcdedit.exe"
    $all = & $bcdEdit /enum all /v 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "bcdedit /enum all /v failed"
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
                }
            }
        }
    }

    return $map
}

function Get-FltmcVolumeRows {
    $rows = fltmc volumes |
        Select-Object -Skip 2 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            if ($_ -match '^\s*(?<dos>[A-Z]:)?\s*(?<vol>\\Device\\[^\s]+)\s+(?<fs>\S+)\s*(?<status>\S+)?\s*$') {
                [PSCustomObject]@{
                    DosName    = $matches['dos']
                    VolumeName = $matches['vol']
                    FileSystem = $matches['fs']
                }
            }
        }

    return @($rows)
}

$recoveryGptType = '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
$bcdVolumes = Get-BcdReferencedNtVolumes
$partitionMetaBySerial = Get-PartitionMetaBySerial
$fltmcRows = Get-FltmcVolumeRows

if (-not $IncludeShadowCopy) {
    $fltmcRows = @($fltmcRows | Where-Object { $_.VolumeName -notmatch '^\\Device\\HarddiskVolumeShadowCopy\d+$' })
}

$result = foreach ($row in $fltmcRows) {
    $sizeGB = $null
    if ($row.DosName) {
        $drive = $row.DosName.TrimEnd(':')
        try {
            $volume = Get-Volume -DriveLetter $drive -ErrorAction Stop
            if ($volume.Size) {
                $sizeGB = [Math]::Round(($volume.Size / 1GB), 2)
            }
        }
        catch {
        }
    }

    $globalRootPath = "\\?\GLOBALROOT$($row.VolumeName)"
    $serial = Get-VolumeSerialHex -Path $globalRootPath

    $meta = $null
    if ($serial -and $partitionMetaBySerial.ContainsKey($serial)) {
        $meta = $partitionMetaBySerial[$serial]
    }

    $partitionType = if ($meta) { $meta.PartitionType } else { $null }
    $gptType = if ($meta) { $meta.GptType } else { $null }
    $mbrType = if ($meta) { $meta.MbrType } else { $null }
    $diskNumber = if ($meta) { $meta.DiskNumber } else { $null }
    $partitionNumber = if ($meta) { $meta.PartitionNumber } else { $null }

    $isRecovery = $false
    if ($partitionType -eq 'Recovery') {
        $isRecovery = $true
    }
    elseif ($gptType -and $gptType.ToString().ToLower() -eq $recoveryGptType) {
        $isRecovery = $true
    }
    elseif ($mbrType -eq 39) {
        $isRecovery = $true
    }

    [PSCustomObject]@{
        InBCD           = ($bcdVolumes -contains $row.VolumeName)
        DosName         = $row.DosName
        VolumeName      = $row.VolumeName
        FileSystem      = $row.FileSystem
        SizeGB          = $sizeGB
        PartitionType   = $partitionType
        GptType         = $gptType
        MbrType         = $mbrType
        DiskNumber      = $diskNumber
        PartitionNumber = $partitionNumber
        IsRecovery      = $isRecovery
    }
}

if ($OnlyBcdReferenced) {
    $result = @($result | Where-Object { $_.InBCD })
}

if (-not [string]::IsNullOrWhiteSpace($ExportCsvPath)) {
    $result | Export-Csv -Path $ExportCsvPath -NoTypeInformation -Encoding UTF8
}

if ($PassThru) {
    return $result
}

$result |
    Sort-Object -Property InBCD, VolumeName -Descending |
    Format-Table InBCD, DosName, VolumeName, FileSystem, SizeGB, PartitionType, DiskNumber, PartitionNumber, IsRecovery -AutoSize
