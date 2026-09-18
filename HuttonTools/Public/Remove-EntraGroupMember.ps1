function Remove-EntraGroupMember {
    <#
    .SYNOPSIS
        Remove one or more users from a Microsoft Entra ID group.

    .DESCRIPTION
        Resolves the group by display name or object ID and each user by UPN, email, or object ID,
        then removes them via Microsoft Graph. Users not in the group are skipped. Supports -WhatIf.
        Cannot be used on dynamic-membership groups.

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
        Remove-EntraGroupMember -GroupName "Sales Team" -Users "user@contoso.com"

    .EXAMPLE
        Remove-EntraGroupMember -GroupId "11111111-2222-3333-4444-555555555555" -CsvPath .\offboarding.csv -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$GroupName,
        [string]$GroupId,
        [string[]]$Users,
        [string]$CsvPath,
        [string]$LogPath
    )

    Invoke-EgmMembershipChange -Action Remove @PSBoundParameters
}
