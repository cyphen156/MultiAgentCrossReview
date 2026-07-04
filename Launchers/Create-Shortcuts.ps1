#requires -Version 5.1
# Generate taskbar-pinnable .lnk shortcuts for every workbench command.
# Each shortcut opens a console (cmd /k) that runs the target PowerShell command.
[CmdletBinding()]
param([string] $OutputDirectory = '')

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot 'Shortcuts' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
# Clear stale shortcuts so regeneration never leaves broken .lnk behind.
Get-ChildItem -LiteralPath $OutputDirectory -Filter *.lnk -ErrorAction SilentlyContinue | Remove-Item -Force
$shell = New-Object -ComObject WScript.Shell

# Name -> command script (relative to repo root). Icon is a shell32.dll index.
$items = @(
    @{ Name = 'All-Start';              Script = 'Start.ps1';                            Icon = '137'; Desc = 'Batch: Start every external sync connector' }
    @{ Name = 'All-Finish';             Script = 'Finish.ps1';                           Icon = '131'; Desc = 'Batch: Finish every external sync connector' }
    @{ Name = 'WorkbenchState-Start';   Script = 'Packages\WorkbenchStateSync\Start.ps1';   Icon = '137'; Desc = 'WorkbenchState: download state from vault' }
    @{ Name = 'WorkbenchState-Finish';  Script = 'Packages\WorkbenchStateSync\Finish.ps1';  Icon = '131'; Desc = 'WorkbenchState: upload state to vault' }
    @{ Name = 'WorkbenchState-Startup'; Script = 'Packages\WorkbenchStateSync\Startup.ps1'; Icon = '176'; Desc = 'WorkbenchState: connect/create external tool' }
    @{ Name = 'AgentSession-Start';     Script = 'Packages\AgentSessionSync\Start.ps1';     Icon = '137'; Desc = 'AgentSession: pull sessions, launch agents' }
    @{ Name = 'AgentSession-Finish';    Script = 'Packages\AgentSessionSync\Finish.ps1';    Icon = '131'; Desc = 'AgentSession: close agents, push sessions' }
    @{ Name = 'AgentSession-Startup';   Script = 'Packages\AgentSessionSync\Startup.ps1';   Icon = '176'; Desc = 'AgentSession: connect/create external tool' }
    @{ Name = 'Project-Sync';           Script = 'ProjectSync\Sync.ps1';                 Icon = '167'; Desc = 'ProjectSync: refresh project source mirror' }
    @{ Name = 'Project-Startup';        Script = 'ProjectSync\Startup.ps1';              Icon = '176'; Desc = 'ProjectSync: create projects.json from example' }
)

foreach ($item in $items) {
    $scriptPath = Join-Path $RepoRoot $item.Script
    $shortcutPath = Join-Path $OutputDirectory "$($item.Name).lnk"
    $sc = $shell.CreateShortcut($shortcutPath)
    $sc.TargetPath = "$env:SystemRoot\System32\cmd.exe"
    $sc.Arguments = "/k powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $sc.WorkingDirectory = $RepoRoot
    $sc.IconLocation = "$env:SystemRoot\System32\shell32.dll,$($item.Icon)"
    $sc.Description = $item.Desc
    $sc.Save()
    Write-Host "Created: $shortcutPath"
}

Write-Host ""
Write-Host "Pin the .lnk files in '$OutputDirectory' to the taskbar for one-click access." -ForegroundColor Cyan
