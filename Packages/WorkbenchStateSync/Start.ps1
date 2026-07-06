#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $ToolRoot = '',
    [string] $StartScript = '',
    [switch] $DryRun,
    [switch] $Force,
    [switch] $SkipGitPull
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)

function Import-WorkbenchStateSyncConfig {
    $candidates = @(
        (Join-Path $PackageRoot 'workbenchstatesync.config.psd1'),
        (Join-Path $RepoRoot 'WorkbenchStateSync.local.psd1')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return Import-PowerShellDataFile -LiteralPath $candidate
        }
    }
    return @{}
}

$config = Import-WorkbenchStateSyncConfig
if (-not $ToolRoot -and $config.ContainsKey('ToolRoot')) { $ToolRoot = [string]$config.ToolRoot }
if (-not $StartScript -and $config.ContainsKey('StartScript')) { $StartScript = [string]$config.StartScript }

if (-not $StartScript) {
    if (-not $ToolRoot) {
        Write-Host 'WorkbenchStateSync Start skipped: no ToolRoot configured.' -ForegroundColor DarkGray
        Write-Host 'Clone MultiAgentWorkbenchStateSync, then set ToolRoot in Packages/WorkbenchStateSync/workbenchstatesync.config.psd1.' -ForegroundColor DarkGray
        exit 0
    }
    $StartScript = Join-Path $ToolRoot 'Launchers\Start.ps1'
}

$StartScript = [IO.Path]::GetFullPath($StartScript)
if (-not (Test-Path -LiteralPath $StartScript)) {
    Write-Host "WorkbenchStateSync Start skipped: script not found: $StartScript" -ForegroundColor Yellow
    exit 0
}

Write-Host 'WorkbenchStateSync Start (adapter)' -ForegroundColor Cyan
Write-Host "  tool:     $StartScript"
Write-Host "  worktree: $RepoRoot"

$toolArgs = @{ WorktreeRoot = $RepoRoot }
if ($Force) { $toolArgs.Force = $true }
if ($SkipGitPull) { $toolArgs.SkipGitPull = $true }

if ($DryRun) {
    Write-Host "dry-run: $StartScript -WorktreeRoot $RepoRoot" -ForegroundColor DarkGray
    exit 0
}

& $StartScript @toolArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'WorkbenchStateSync Start complete.' -ForegroundColor Green
