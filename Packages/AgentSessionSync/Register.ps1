#requires -Version 5.1
# Register an existing AgentSessionVault (or AgentSessionSync tool) folder into the
# local registry UserSettings/sync-tools.json. Validates the required launchers first.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ToolRoot,
    [switch] $Disable,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagesRoot = Split-Path -Parent $PackageRoot
$RepoRoot = Split-Path -Parent $PackagesRoot
. (Join-Path $PackagesRoot 'SyncToolRegistry.ps1')

$toolName = 'AgentSessionSync'
$defaults = Get-SyncToolDefaults $toolName
$abs = Resolve-ToolRootPath $RepoRoot $ToolRoot

Write-Host "Register $toolName" -ForegroundColor Cyan
Write-Host "  ToolRoot (as given): $ToolRoot"
Write-Host "  ToolRoot (resolved): $abs"

foreach ($req in @($defaults.StartScript, $defaults.FinishScript)) {
    $p = Join-Path $abs $req
    if (-not (Test-Path -LiteralPath $p)) { throw "Required launcher missing: $p" }
    Write-Host "  found: $req" -ForegroundColor DarkGray
}

if ($DryRun) {
    Write-Host "dry-run: would register $toolName -> '$ToolRoot' in $(Get-SyncRegistryPath $RepoRoot)" -ForegroundColor DarkGray
    exit 0
}

$path = Write-SyncToolRegistration -RepoRoot $RepoRoot -ToolName $toolName -ToolRoot $ToolRoot -Enabled (-not $Disable)
Write-Host "Registered $toolName -> $path" -ForegroundColor Green
