$moduleRoot = $PSScriptRoot

# A foreach statement, not ForEach-Object: the dot-source operator must run in module
# scope so the loaded functions are visible to each other and to Export-ModuleMember.
foreach ($folder in @('Private', 'Public')) {
    $folderPath = Join-Path $moduleRoot $folder
    if (-not (Test-Path $folderPath)) { continue }

    foreach ($file in (Get-ChildItem -Path $folderPath -Filter '*.ps1' -File)) {
        . $file.FullName
    }
}

$publicPath = Join-Path $moduleRoot 'Public'
$publicFunctions = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' -File |
    Select-Object -ExpandProperty BaseName)

Export-ModuleMember -Function $publicFunctions
