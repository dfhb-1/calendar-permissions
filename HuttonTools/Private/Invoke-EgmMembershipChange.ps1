function Invoke-EgmMembershipChange {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Add', 'Remove')][string]$Action,
        [string]$GroupName,
        [string]$GroupId,
        [string[]]$Users,
        [string]$CsvPath,
        [string]$LogPath
    )

    Connect-HbGraph

    $group = Resolve-EgmGroup -GroupName $GroupName -GroupId $GroupId -LogPath $LogPath
    Write-HbLog "Target group: $($group.DisplayName) ($($group.Id))" 'INFO' $LogPath

    $userIdentifiers = Get-EgmUserList -Users $Users -CsvPath $CsvPath
    Write-HbLog "Processing $($userIdentifiers.Count) user(s) - action: $Action" 'INFO' $LogPath

    # Pull membership once rather than per user
    $memberIds = @(Get-MgGroupMember -GroupId $group.Id -All | Select-Object -ExpandProperty Id)

    $results = foreach ($identifier in $userIdentifiers) {

        $row = [ordered]@{ User = $identifier; Action = $Action; Result = ''; Detail = '' }

        try {
            $user = Get-MgUser -UserId $identifier -ErrorAction Stop
        }
        catch {
            $row.Result = 'Failed'
            $row.Detail = 'User not found'
            Write-HbLog "User not found: $identifier" 'ERROR' $LogPath
            [PSCustomObject]$row
            continue
        }

        $target   = "$($user.DisplayName) <$($user.UserPrincipalName)> -> $($group.DisplayName)"
        $isMember = $memberIds -contains $user.Id

        if ($Action -eq 'Add') {
            if ($isMember) {
                $row.Result = 'Skipped'; $row.Detail = 'Already a member'
                Write-HbLog "Skipped (already a member): $target" 'INFO' $LogPath
            }
            elseif ($PSCmdlet.ShouldProcess($target, 'Add to group')) {
                try {
                    $odataId = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
                    New-MgGroupMemberByRef -GroupId $group.Id -OdataId $odataId -Confirm:$false -ErrorAction Stop
                    $row.Result = 'Success'
                    Write-HbLog "Added: $target" 'INFO' $LogPath
                }
                catch {
                    $row.Result = 'Failed'; $row.Detail = $_.Exception.Message
                    Write-HbLog "Failed to add: $target - $($_.Exception.Message)" 'ERROR' $LogPath
                }
            }
        }
        else {
            if (-not $isMember) {
                $row.Result = 'Skipped'; $row.Detail = 'Not a member'
                Write-HbLog "Skipped (not a member): $target" 'INFO' $LogPath
            }
            elseif ($PSCmdlet.ShouldProcess($target, 'Remove from group')) {
                try {
                    Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id -Confirm:$false -ErrorAction Stop
                    $row.Result = 'Success'
                    Write-HbLog "Removed: $target" 'INFO' $LogPath
                }
                catch {
                    $row.Result = 'Failed'; $row.Detail = $_.Exception.Message
                    Write-HbLog "Failed to remove: $target - $($_.Exception.Message)" 'ERROR' $LogPath
                }
            }
        }

        [PSCustomObject]$row
    }

    Write-HbLog "---- Summary ----" 'INFO' $LogPath
    $results | Group-Object Result | ForEach-Object { Write-HbLog "$($_.Name): $($_.Count)" 'INFO' $LogPath }
    if ($LogPath) { Write-HbLog "Log written to: $LogPath" 'INFO' $LogPath }

    return $results
}
