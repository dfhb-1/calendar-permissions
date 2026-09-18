<#
.SYNOPSIS
    Install the HuttonTools PowerShell module for the current user.

.DESCRIPTION
    Runs three ways:

      irm https://raw.githubusercontent.com/dfhb-1/hutton-tools/main/install.ps1 | iex
      ./install.ps1                       (from a clone)
      ./install.ps1 -Source ./HuttonTools (from any folder holding the module)

    Self-contained on purpose: piped through iex there is no repo on disk, so this script
    dot-sources nothing.

.PARAMETER Version
    Release tag to install, e.g. v1.2.0. Defaults to the latest release.

.PARAMETER Source
    Install from this folder instead of downloading. Must contain HuttonTools.psd1.

.PARAMETER KeepLegacy
    Leave the superseded CalendarPermissions and EntraGroupMembers modules in place.

.EXAMPLE
    ./install.ps1

.EXAMPLE
    ./install.ps1 -Version v1.0.0
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$Source,
    [switch]$KeepLegacy
)

$ErrorActionPreference = 'Stop'

$repo       = 'dfhb-1/hutton-tools'
$moduleName = 'HuttonTools'
$tempRoot   = $null

# Duplicated as HuttonTools/Private/Get-HbInstallPath.ps1 — this script cannot import the
# module it is installing, so the logic lives in both places. Keep the two in sync.
function Get-HbInstallRoot {
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

try {
    # ---- Resolve where the module is coming from -------------------------------------
    if ($Source) {
        $sourceModule = (Resolve-Path -Path $Source).Path
        if (-not (Test-Path (Join-Path $sourceModule 'HuttonTools.psd1'))) {
            throw "-Source folder does not contain HuttonTools.psd1: $sourceModule"
        }
        $sourceKind = 'path'
    }
    # An explicit -Version means "install that release", so it outranks the working tree.
    elseif (-not $Version -and $PSScriptRoot -and (Test-Path (Join-Path (Join-Path $PSScriptRoot $moduleName) 'HuttonTools.psd1'))) {
        $sourceModule = Join-Path $PSScriptRoot $moduleName
        $sourceKind = 'clone'
    }
    else {
        $sourceKind = 'release'

        if ($Version) {
            $url        = "https://github.com/$repo/releases/download/$Version/HuttonTools.zip"
            $notFound   = "No release found (tag $Version)."
        }
        else {
            $url        = "https://github.com/$repo/releases/latest/download/HuttonTools.zip"
            $notFound   = "No releases published yet."
        }

        # Windows PowerShell 5.1 still defaults to TLS 1.0, which github.com refuses.
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("HuttonTools-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        $zipPath = Join-Path $tempRoot 'HuttonTools.zip'
        Write-Host "Downloading $url" -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        }
        catch {
            # WebException (5.1) and HttpResponseException (7.x) both carry .Response.
            if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
                throw $notFound
            }
            throw
        }

        $extractRoot = Join-Path $tempRoot 'extract'
        Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

        # Don't assume a fixed depth: the release zip may or may not have a wrapping folder.
        $found = Get-ChildItem -Path $extractRoot -Recurse -Filter 'HuttonTools.psd1' -File |
            Select-Object -First 1
        if (-not $found) {
            throw "Downloaded archive does not contain HuttonTools.psd1."
        }
        $sourceModule = $found.Directory.FullName
    }

    # ---- Install ----------------------------------------------------------------------
    $installRoot = Get-HbInstallRoot
    if (-not (Test-Path $installRoot)) {
        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    }

    if (-not $KeepLegacy) {
        foreach ($legacy in @('CalendarPermissions', 'EntraGroupMembers')) {
            $legacyPath = Join-Path $installRoot $legacy
            if (Test-Path $legacyPath) {
                Remove-Item -Path $legacyPath -Recurse -Force
                Write-Host "Removed superseded module $legacy (its commands are now in HuttonTools)." -ForegroundColor Yellow
            }
        }
    }

    $destination = Join-Path $installRoot $moduleName
    if (Test-Path $destination) {
        Remove-Item -Path $destination -Recurse -Force
    }
    Copy-Item -Path $sourceModule -Destination $destination -Recurse -Force

    $installedManifest = Join-Path $destination 'HuttonTools.psd1'
    try {
        $installed = Test-ModuleManifest -Path $installedManifest
    }
    catch {
        Remove-Item -Path $destination -Recurse -Force -ErrorAction SilentlyContinue
        throw "Installed manifest failed validation: $($_.Exception.Message)"
    }

    $installRecord = [ordered]@{
        version     = $installed.Version.ToString()
        source      = $sourceKind
        installedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        repo        = $repo
    }
    $installRecord | ConvertTo-Json | Set-Content -Path (Join-Path $destination 'install.json') -Encoding UTF8

    # ---- Dependencies (reported, never installed for the user) -------------------------
    $missing = @(
        @('ExchangeOnlineManagement', 'Microsoft.Graph.Groups', 'Microsoft.Graph.Users') |
            Where-Object { -not (Get-Module -ListAvailable -Name $_) }
    )
    if ($missing.Count -gt 0) {
        Write-Host "Missing dependencies: $($missing -join ', ')" -ForegroundColor Yellow
        if ($missing -contains 'ExchangeOnlineManagement') {
            Write-Host "  Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
        }
        if (($missing -contains 'Microsoft.Graph.Groups') -or ($missing -contains 'Microsoft.Graph.Users')) {
            Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser    # covers both Graph modules" -ForegroundColor Yellow
        }
    }

    Write-Host "HuttonTools $($installed.Version) installed to $destination." -ForegroundColor Green
    Write-Host "Open a new PowerShell session, or run: Import-Module HuttonTools -Force" -ForegroundColor Cyan
}
catch {
    Write-Host "Install failed: $($_.Exception.Message)" -ForegroundColor Red
    # `exit` would close the caller's console on the `irm | iex` path, so only set an exit
    # code when running as a real script file.
    if ($PSCommandPath) { exit 1 }
    return
}
finally {
    if ($tempRoot -and (Test-Path $tempRoot)) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
