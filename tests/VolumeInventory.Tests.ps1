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
}
