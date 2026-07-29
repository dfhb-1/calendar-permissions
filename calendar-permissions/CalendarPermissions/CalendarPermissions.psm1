function Add-CalendarPermission {
    [CmdletBinding()]
    param()

    $mailbox = Read-Host "Enter the mailbox email address (calendar owner)"
    $user = Read-Host "Enter the user/group to grant access to (e.g. ~HCC Everyone)"
    $accessRights = Read-Host "Enter access rights (default: Reviewer)"

    if ([string]::IsNullOrWhiteSpace($accessRights)) {
        $accessRights = "Reviewer"
    }

    Add-MailboxFolderPermission -Identity "$mailbox`:\Calendar" -User $user -AccessRights $accessRights
}

Export-ModuleMember -Function Add-CalendarPermission