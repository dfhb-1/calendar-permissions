@{
    RootModule           = 'HuttonTools.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'f122e299-91d1-48c7-b823-235232fda693'
    Author               = 'Hutton Builds IT'
    CompanyName          = 'Hutton Builds'
    Copyright            = '(c) 2026 Hutton Builds. All rights reserved.'
    Description          = 'Microsoft 365 administration tools for Exchange Online calendars and Microsoft Entra ID group membership.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport    = @(
        'Add-CalendarPermission',
        'Add-EntraGroupMember',
        'Remove-EntraGroupMember'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Microsoft365', 'ExchangeOnline', 'Entra', 'AzureAD', 'Graph', 'Groups', 'Calendar')
            ProjectUri = 'https://github.com/dfhb-1/hutton-tools'

            # Declared as external, not RequiredModules: importing HuttonTools must succeed on a
            # machine with neither SDK installed. The Connect-Hb* helpers check at call time.
            ExternalModuleDependencies = @(
                'ExchangeOnlineManagement',
                'Microsoft.Graph.Groups',
                'Microsoft.Graph.Users'
            )
        }
    }
}
