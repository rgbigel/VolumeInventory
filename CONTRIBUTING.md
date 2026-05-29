# Contributing

## Local Validation

1. Run parser check:

powershell -NoProfile -Command "$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('.\\src\\VolumeInventory.ps1', [ref]$null, [ref]$errors) | Out-Null; if ($errors) { $errors | ForEach-Object { $_.Message }; exit 1 }"

2. Run tests:

powershell -NoProfile -Command "Invoke-Pester -Path .\\tests -Output Detailed"

## Change Process

- Update header metadata in src/VolumeInventory.ps1 when behavior changes.
- Add an entry to docs/CHANGELOG.md.
- Keep tests in tests/VolumeInventory.Tests.ps1 aligned with script parameters and contract.
