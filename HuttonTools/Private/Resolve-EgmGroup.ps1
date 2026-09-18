function Resolve-EgmGroup {
    param([string]$GroupName, [string]$GroupId, [string]$LogPath)

    if (-not $GroupId -and -not $GroupName) {
        throw "Specify either -GroupName or -GroupId."
    }

    if ($GroupId) {
        return Get-MgGroup -GroupId $GroupId -ErrorAction Stop
    }

    $escaped = $GroupName -replace "'", "''"
    $candidates = @(Get-MgGroup -Filter "displayName eq '$escaped'")

    if ($candidates.Count -eq 0) {
        throw "No group found with display name '$GroupName'. Try: Get-MgGroup -Filter `"startswith(displayName,'$escaped')`""
    }
    if ($candidates.Count -gt 1) {
        Write-HbLog "Multiple groups matched '$GroupName':" 'ERROR' $LogPath
        $candidates | ForEach-Object { Write-HbLog "  $($_.DisplayName) - $($_.Id)" 'ERROR' $LogPath }
        throw "Ambiguous group name - rerun with -GroupId."
    }
    return $candidates[0]
}
