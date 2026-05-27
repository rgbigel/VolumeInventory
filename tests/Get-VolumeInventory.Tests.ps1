Describe 'Get-VolumeInventory script' {
    It 'parses without syntax errors' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\Get-VolumeInventory.ps1'
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'contains documented parameters' {
        $scriptPath = Join-Path $PSScriptRoot '..\src\Get-VolumeInventory.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $paramBlock = $ast.ParamBlock
        $paramNames = @($paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })

        $paramNames | Should -Contain 'IncludeShadowCopy'
        $paramNames | Should -Contain 'OnlyBcdReferenced'
        $paramNames | Should -Contain 'PassThru'
        $paramNames | Should -Contain 'ExportCsvPath'
    }
}
