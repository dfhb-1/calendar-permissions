function Connect-HbGraph {
    foreach ($mod in @('Microsoft.Graph.Groups', 'Microsoft.Graph.Users')) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            throw "Required module '$mod' is not installed. Run: Install-Module Microsoft.Graph -Scope CurrentUser"
        }
    }
    if (-not (Get-MgContext)) {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes 'GroupMember.ReadWrite.All', 'User.Read.All', 'Group.Read.All' -NoWelcome
    }
}
