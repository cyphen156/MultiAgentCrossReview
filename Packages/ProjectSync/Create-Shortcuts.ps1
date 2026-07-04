#requires -Version 5.1
[CmdletBinding()]
param([string] $OutputDirectory = '')

$ErrorActionPreference = 'Stop'

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $PSScriptRoot 'Shortcuts'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$shell = New-Object -ComObject WScript.Shell

$items = @(
    @{
        Name = 'Start'
        Cmd = 'Start.cmd'
        Icon = "$env:SystemRoot\System32\shell32.dll,137"
        Description = 'Start ProjectSync'
    }
)

foreach ($item in $items) {
    $cmdPath = Join-Path $PSScriptRoot $item.Cmd
    $shortcutPath = Join-Path $OutputDirectory "$($item.Name).lnk"
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$env:SystemRoot\System32\cmd.exe"
    $shortcut.Arguments = "/k `"$cmdPath`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = $item.Icon
    $shortcut.Description = $item.Description
    $shortcut.Save()
    Write-Host "Created: $shortcutPath"
}
