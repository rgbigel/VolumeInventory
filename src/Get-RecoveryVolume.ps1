<#
.NAME
    Get-RecoveryVolume.ps1

.VERSION
    1.0.0

.DESCRIPTION
    Extracts WinRE recovery partition information from ReAgent.xml on a mounted volume.
    Identifies disk and partition numbers (0-based) for the Windows Recovery Environment.

.AUTHOR
    System Tools

.REPOSITORY
    d:\Git_Repositories\GetRecoveryVolume
    (Command line deployment: d:\OneDrive\cmd\Get-RecoveryVolume.ps1)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$p,

    [switch]$t,
    [switch]$h
)

<#
.SYNOPSIS
    Extracts WinRE recovery partition information from ReAgent.xml on a mounted volume.

.DESCRIPTION
    Reads ReAgent.xml from the given mounted volume, extracts the disk number and
    partition number of the WinRE recovery partition, and outputs them to the terminal.
    Exits with code 1 if ReAgent.xml is not found or the path cannot be parsed.

.PARAMETER p
    Path to the mounted volume containing the Windows installation (e.g. C: or D:\).
    Required.

.PARAMETER t
    Enables trace/diagnostic output.

.PARAMETER h
    Shows this help and exits.

.EXAMPLE
    .\Get-RecoveryVolume.ps1 -p C:
    .\Get-RecoveryVolume.ps1 -p C: -t
#>

if ($h) {
    Write-Host "Get-RecoveryVolume.ps1"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  Get-RecoveryVolume.ps1 -p <VolumePath> [-t] [-h]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -p             Path to the mounted volume (e.g. C: or D:\). Required."
    Write-Host "  -t             Trace/diagnostic mode"
    Write-Host "  -h             Show this help"
    Write-Host ""
    exit 0
}

function Write-VerboseIf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if ($Enabled) { Write-Host "[-t] $Message" -ForegroundColor DarkGray }
}

# Normalize path
$vol = $p.TrimEnd('\')

# ReAgent.xml location
$xmlPath = Join-Path $vol "Windows\System32\Recovery\ReAgent.xml"

Write-VerboseIf -Message "Checking for ReAgent.xml at: $xmlPath" -Enabled $t.IsPresent

if (-not (Test-Path $xmlPath)) {
    Write-Host "ReAgent.xml not found at: $xmlPath" -ForegroundColor Yellow
    exit 1
}

Write-VerboseIf -Message "ReAgent.xml found. Loading..." -Enabled $t.IsPresent

# Load XML
try {
    [xml]$xml = Get-Content $xmlPath -ErrorAction Stop
}
catch {
    Write-Host "Failed to parse ReAgent.xml: $_" -ForegroundColor Red
    exit 1
}

# Extract WinRE location
$node = $xml.WindowsRE.WinreLocation

if (-not $node) {
    Write-Host "WinreLocation node missing in ReAgent.xml" -ForegroundColor Red
    exit 1
}

$offset = [long]$node.offset

Write-VerboseIf -Message "WinreLocation offset=$offset" -Enabled $t.IsPresent

# Resolve disk and partition from byte offset (id in XML is not the physical disk number)
try {
    $partition = Get-Partition -ErrorAction Stop |
                 Where-Object { $_.Offset -eq $offset } |
                 Select-Object -First 1
}
catch {
    Write-Host "Failed to query partitions: $_" -ForegroundColor Red
    exit 1
}

if (-not $partition) {
    Write-Host "No partition found at offset $offset on any disk" -ForegroundColor Red
    exit 1
}

$disk = $partition.DiskNumber                    # Get-Partition: 0-based
$part = $partition.PartitionNumber - 1           # Get-Partition: 1-based -> convert to 0-based

Write-VerboseIf -Message "Resolved DiskNumber=$disk PartitionNumber=$part" -Enabled $t.IsPresent

# Get volume label for source volume
$driveLetter = $vol.TrimEnd(':')
$volInfo = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
$volLabel = if ($volInfo) { $volInfo.FileSystemLabel } else { "(no label)" }

# Output result
Write-Host ""
Write-Host "WinRE Recovery Partition Information" -ForegroundColor Cyan
Write-Host "-----------------------------------"
Write-Host "ReAgent.xml Path : $xmlPath"
Write-Host "Source Volume    : $vol $volLabel"
Write-Host ""
Write-Host "Disk / Partition #:    D${disk}P${part}"
Write-Host ""
