[CmdletBinding()]
param()

# File:       VolumeInventory.Tests.ps1
# Version:    2.6.0
# Author:     Rolf
# Created:    2026-05-27
# Updated:    2026-08-16
# Purpose:
#   Validates VolumeInventory parser, parameter, and execution contracts.
# Changelog:
#   2.6.0 - Added live execution and contract validation tests under elevated test runner.
#   2.5.0 - Added script metadata and lifecycle structure coverage.

Describe 'VolumeInventory script contracts' {
    It 'parses without syntax errors' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'contains documented parameters' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $paramBlock = $ast.ParamBlock
        $paramNames = @($paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

        ($paramNames -contains 'IncludeShadowCopy') | Should -Be $true
        ($paramNames -contains 'OnlyBcdReferenced') | Should -Be $true
        ($paramNames -contains 'PassThru') | Should -Be $true
        ($paramNames -contains 'ExportCsvPath') | Should -Be $true
    }

    It 'keeps helper functions advanced and self-contained' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

        foreach ($function in $functions) {
            $function.Body.ParamBlock | Should -Not -BeNullOrEmpty
            ($function.Body.ParamBlock.Attributes.TypeName.FullName -contains 'CmdletBinding') | Should -Be $true
        }
    }

    It 'executes cleanly with -PassThru and returns valid volume records' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $rows = & $scriptPath -PassThru
        $rows | Should -Not -BeNullOrEmpty
        @($rows).Count | Should -BeGreaterThan 0

        $firstRow = $rows | Select-Object -First 1
        ($firstRow.PSObject.Properties.Name -contains 'VolumeName') | Should -Be $true
        ($firstRow.PSObject.Properties.Name -contains 'StartOffset') | Should -Be $true
        ($firstRow.PSObject.Properties.Name -contains 'Role') | Should -Be $true
        ($firstRow.PSObject.Properties.Name -contains 'DiskNumber') | Should -Be $true
    }
}
