# Optional: syntax check using the ScriptDom library already installed with SSMS.
# This does not connect to SQL Server and does not validate SQL runtime behavior.
param([string]$ScriptDomPath = '')
$ErrorActionPreference = 'Stop'
if (-not $ScriptDomPath) {
    $ScriptDomPath = Join-Path $env:ProgramFiles 'Microsoft SQL Server Management Studio 21\Release\Common7\IDE\Extensions\Application\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
}
if (-not (Test-Path -LiteralPath $ScriptDomPath)) {
    throw 'ScriptDom not found. Pass -ScriptDomPath with the installed DLL location; no package installation is required.'
}
Add-Type -Path $ScriptDomPath
$parser = New-Object Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser -ArgumentList $true
$projectRoot = Split-Path -Parent $PSScriptRoot
$results = @()
foreach ($sqlFile in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'sql') -Filter '*.sql') {
    $reader = New-Object System.IO.StringReader ([System.IO.File]::ReadAllText($sqlFile.FullName))
    $parseErrors = $null
    try { $fragment = $parser.Parse($reader, [ref]$parseErrors) }
    finally { $reader.Dispose() }
    $results += [pscustomobject]@{
        File = $sqlFile.Name
        SyntaxErrors = $parseErrors.Count
        Errors = @($parseErrors | Select-Object Number,Line,Column,Message)
        CheckType = 'syntax_only'
    }
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $projectRoot 'outputs\syntax_validation.json') -Encoding UTF8
$results | Select-Object File,SyntaxErrors,CheckType
if (@($results | Where-Object SyntaxErrors -GT 0).Count -gt 0) {
    throw 'SQL syntax validation failed. See outputs/syntax_validation.json.'
}
