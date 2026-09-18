function Add-EntraGroupMember {
    <#
    .SYNOPSIS
        Add one or more users to a Microsoft Entra ID group.

    .DESCRIPTION
        Resolves the group by display name or object ID and each user by UPN, email, or object ID,
        then adds them via Microsoft Graph. Users already in the group are skipped. Supports -WhatIf.

    .PARAMETER GroupName
        Group display name (must resolve to exactly one group).

    .PARAMETER GroupId
        Group object ID (GUID). Use this when display names are ambiguous.

    .PARAMETER Users
        One or more UPNs, email addresses, or object IDs.

    .PARAMETER CsvPath
        CSV file with a UserPrincipalName, Email, or UPN column. Can be combined with -Users.

    .PARAMETER LogPath
        Optional path for a run log. Omit to log to the console only.

    .EXAMPLE
        Add-EntraGroupMember -GroupName "Sales Team" -Users "user@contoso.com"

    .EXAMPLE
        Add-EntraGroupMember -GroupName "All Staff" -CsvPath .\newhires.csv -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$GroupName,
        [string]$GroupId,
        [string[]]$Users,
        [string]$CsvPath,
        [string]$LogPath
    )

    Invoke-EgmMembershipChange -Action Add @PSBoundParameters
}
