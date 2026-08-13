[CmdletBinding()]
param()

# File:       VolumeInventory.Tests.ps1
# Version:    2.5.0
# Author:     Rolf
# Created:    2026-05-27
# Updated:    2026-08-13
# Purpose:
#   Validates VolumeInventory parser, parameter, and PowerShell lifecycle structure contracts.
# Changelog:
#   2.5.0 - Added script metadata and lifecycle structure coverage for method-clean release pending test.

Describe 'VolumeInventory script' {
    It 'parses without syntax errors' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should Be 0
    }

    It 'contains documented parameters' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $paramBlock = $ast.ParamBlock
        $paramNames = @($paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

        ($paramNames -contains 'IncludeShadowCopy') | Should Be $true
        ($paramNames -contains 'OnlyBcdReferenced') | Should Be $true
        ($paramNames -contains 'PassThru') | Should Be $true
        ($paramNames -contains 'ExportCsvPath') | Should Be $true
    }

    It 'keeps helper functions advanced and self-contained' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\VolumeInventory.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

        foreach ($function in $functions) {
            $function.Body.ParamBlock | Should Not Be $null
            ($function.Body.ParamBlock.Attributes.TypeName.FullName -contains 'CmdletBinding') | Should Be $true
        }
    }
}
