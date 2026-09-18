function Connect-HbExchange {
    if (-not (Get-Module -ListAvailable -Name 'ExchangeOnlineManagement')) {
        throw "Required module 'ExchangeOnlineManagement' is not installed. Run: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
    }

    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    # Get-ConnectionInformation only exists in EXO v3+; on older versions fall through and
    # let Connect-ExchangeOnline decide what to do about an existing session.
    if (Get-Command -Name 'Get-ConnectionInformation' -ErrorAction SilentlyContinue) {
        $active = @(Get-ConnectionInformation | Where-Object { $_.State -eq 'Connected' })
        if ($active.Count -gt 0) { return }
    }

    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false
}
