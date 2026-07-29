$repoModulePath = Join-Path $PSScriptRoot "CalendarPermissions"

# Determine the correct user module path for this OS
if ($IsWindows) {
    $userModulesRoot = Join-Path $HOME "Documents\PowerShell\Modules"
} else {
    $userModulesRoot = Join-Path $HOME ".local/share/powershell/Modules"
}

$destination = Join-Path $userModulesRoot "CalendarPermissions"

if (!(Test-Path $userModulesRoot)) {
    New-Item -ItemType Directory -Path $userModulesRoot -Force | Out-Null
}

Copy-Item -Path $repoModulePath -Destination $destination -Recurse -Force

Write-Host "CalendarPermissions module installed to: $destination" -ForegroundColor Green
Write-Host "Run 'Import-Module CalendarPermissions' to load it, or add that line to your `$PROFILE to always have it available." -ForegroundColor Cyan