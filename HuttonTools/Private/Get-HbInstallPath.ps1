function Get-HbInstallPath {
    # Duplicated as Get-HbInstallRoot in install.ps1 at the repo root; that script runs before
    # this module exists (and via `irm | iex` with no repo on disk), so it cannot import this.
    # Keep the two in sync.
    $onWindows = ($PSVersionTable.PSEdition -eq 'Desktop')
    if (-not $onWindows -and (Get-Variable -Name 'IsWindows' -ErrorAction SilentlyContinue)) {
        $onWindows = $IsWindows
    }

    if ($onWindows) {
        # GetFolderPath, not $HOME\Documents: it follows a OneDrive-redirected Documents folder.
        $documents = [Environment]::GetFolderPath('MyDocuments')
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            return (Join-Path $documents 'WindowsPowerShell\Modules')
        }
        return (Join-Path $documents 'PowerShell\Modules')
    }

    return (Join-Path $HOME '.local/share/powershell/Modules')
}
