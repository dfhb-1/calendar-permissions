function Get-EgmUserList {
    param([string[]]$Users, [string]$CsvPath)

    $list = [System.Collections.Generic.List[string]]::new()

    if ($CsvPath) {
        if (-not (Test-Path $CsvPath)) { throw "CSV file not found: $CsvPath" }
        $csv = @(Import-Csv -Path $CsvPath)
        if ($csv.Count -eq 0) { throw "CSV file is empty: $CsvPath" }
        $column = $csv[0].PSObject.Properties.Name |
            Where-Object { $_ -in @('UserPrincipalName', 'Email', 'UPN') } |
            Select-Object -First 1
        if (-not $column) { throw "CSV must contain a UserPrincipalName, Email, or UPN column." }
        $csv.$column | ForEach-Object { $list.Add($_) }
    }

    if ($Users) { $Users | ForEach-Object { $list.Add($_) } }

    $result = @($list | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Select-Object -Unique)
    if ($result.Count -eq 0) { throw "No users specified. Use -Users and/or -CsvPath." }
    return $result
}
