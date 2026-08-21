# Contributing

Version: 2.5.1

## Local Validation

1. Run parser check:

pwsh -NoProfile -Command "$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile('.\\src\\VolumeInventory.ps1', [ref]$null, [ref]$errors) | Out-Null; if ($errors) { $errors | ForEach-Object { $_.Message }; exit 1 }"

2. Run tests:

pwsh -NoProfile -Command "Invoke-Pester -Path .\\tests"

3. Before changing installer behavior, verify that the installer still assumes exactly one distributable source script and aborts when additional source scripts or module dependency declarations are detected.

## Change Process

- Update header metadata in src/VolumeInventory.ps1 when behavior changes.
- Add an entry to docs/CHANGELOG.md.
- Keep tests in tests/VolumeInventory.Tests.ps1 aligned with script parameters and contract.
- Keep README installer notes aligned with scripts/Install-VolumeInventory.ps1 guardrails.
