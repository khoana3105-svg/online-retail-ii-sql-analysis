# Dedicated portfolio database only. CSV path is substituted in memory, not saved.
param([string]$Server = 'localhost', [string]$CsvPath = '', [switch]$Load, [string]$ProjectDirectory = '')
$ErrorActionPreference = 'Stop'
$projectRoot = if ($ProjectDirectory) { $ProjectDirectory } else { Split-Path -Parent $PSScriptRoot }
$out = Join-Path $projectRoot 'outputs\sql_server'
[void][IO.Directory]::CreateDirectory($out)
$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$builder['Data Source'] = $Server
$builder['Initial Catalog'] = 'master'
$builder['Integrated Security'] = $true
$builder['Connect Timeout'] = 10
$builder['Encrypt'] = $true
$builder['TrustServerCertificate'] = $true
$connection = New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
$results = @()
$files = @('02_thuc_hanh.sql', '03_time_comparisons.sql')
if ($Load) {
    if (-not $CsvPath) { throw 'Supply -CsvPath when loading the isolated portfolio database.' }
    $files = @('01_nhap_du_lieu.sql') + $files
}
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 120
    $command.CommandText = "SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128))"
    $version = [string]$command.ExecuteScalar()
    foreach ($file in $files) {
        $text = [IO.File]::ReadAllText((Join-Path $projectRoot ('sql\' + $file)))
        if ($file -eq '01_nhap_du_lieu.sql') {
            $text = $text.Replace('C:\SQLData\retail_raw.csv', $CsvPath.Replace("'", "''"))
        }
        $resultIndex = 0
        foreach ($batch in [regex]::Split($text, '(?im)^\s*GO\s*\r?$')) {
            if (-not $batch.Trim()) { continue }
            $command.CommandText = $batch
            $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet
            try {
                [void]$adapter.Fill($dataset)
                foreach ($table in $dataset.Tables) {
                    $resultIndex++
                    $name = '{0}_{1:d2}.csv' -f [IO.Path]::GetFileNameWithoutExtension($file), $resultIndex
                    $records = @(
                        foreach ($row in $table.Rows) {
                            $record = [ordered]@{}
                            foreach ($column in $table.Columns) {
                                $value = $row[$column.ColumnName]
                                if ($value -is [DBNull]) { $value = $null }
                                elseif ($value -is [datetime]) { $value = $value.ToString('yyyy-MM-ddTHH:mm:ss') }
                                elseif ($value -is [IFormattable]) { $value = $value.ToString($null, [Globalization.CultureInfo]::InvariantCulture) }
                                $record[$column.ColumnName] = $value
                            }
                            [pscustomobject]$record
                        }
                    )
                    if ($records.Count) {
                        $records | Export-Csv -LiteralPath (Join-Path $out $name) -Encoding UTF8 -NoTypeInformation
                    } else {
                        $header = (@($table.Columns | ForEach-Object { '"' + $_.ColumnName + '"' }) -join ',')
                        [IO.File]::WriteAllText((Join-Path $out $name), $header + "`n", [Text.Encoding]::UTF8)
                    }
                    $results += [pscustomobject]@{ File=$name; Source=$file; Rows=$table.Rows.Count; Columns=@($table.Columns | ForEach-Object ColumnName) }
                }
            } finally { $adapter.Dispose(); $dataset.Dispose() }
        }
    }
    $manifest = @{Database='OnlineRetailII_Portfolio'; SqlServerVersion=$version; ExecutedAtUTC=[datetime]::UtcNow.ToString('o'); ResultSets=$results}
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'execution.json') -Encoding UTF8
    Write-Output ('Executed ' + $results.Count + ' result sets in OnlineRetailII_Portfolio.')
} finally {
    if ($connection.State -eq 'Open') {
        $rollback = $connection.CreateCommand()
        $rollback.CommandText = 'IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;'
        [void]$rollback.ExecuteNonQuery()
    }
    $connection.Dispose()
}
