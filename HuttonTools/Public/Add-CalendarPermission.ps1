function Add-CalendarPermission {
    <#
    .SYNOPSIS
        Grant a user or group access to a mailbox's calendar.

    .DESCRIPTION
        Adds a permission entry to the Calendar folder of an Exchange Online mailbox via
        Add-MailboxFolderPermission. Connects to Exchange Online first if there is no active
        session. Supports -WhatIf.

        Called with no arguments, the mandatory parameters prompt, so it can still be used
        interactively.

    .PARAMETER Mailbox
        The mailbox that owns the calendar, by primary SMTP address.

    .PARAMETER User
        The user or group being granted access, by SMTP address, alias, or display name.

    .PARAMETER AccessRights
        The Exchange folder role to grant. Defaults to Reviewer (can read all items, change nothing).

    .EXAMPLE
        Add-CalendarPermission -Mailbox conference-room@contoso.com -User user@contoso.com

        Grants read-only access to the conference room calendar.

    .EXAMPLE
        Add-CalendarPermission -Mailbox director@contoso.com -User assistant@contoso.com -AccessRights Editor

        Grants full edit access, so the assistant can create and change appointments.

    .EXAMPLE
        Add-CalendarPermission -Mailbox director@contoso.com -User "Sales Team" -AccessRights LimitedDetails -WhatIf

        Previews granting a group limited visibility, without applying the change.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Mailbox,

        [Parameter(Mandatory)]
        [string]$User,

        [ValidateSet('None', 'AvailabilityOnly', 'LimitedDetails', 'Contributor', 'Reviewer',
            'NonEditingAuthor', 'Author', 'PublishingAuthor', 'Editor', 'PublishingEditor', 'Owner')]
        [string]$AccessRights = 'Reviewer'
    )

    Connect-HbExchange

    $identity = "$Mailbox`:\Calendar"

    if ($PSCmdlet.ShouldProcess("$identity for $User", "Grant $AccessRights")) {
        Add-MailboxFolderPermission -Identity $identity -User $User -AccessRights $AccessRights
    }
}
