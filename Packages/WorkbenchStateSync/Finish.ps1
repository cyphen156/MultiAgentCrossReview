#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $ToolRoot = '',
    [string] $FinishScript = '',
    [string] $CommitMessage = '',
    [switch] $DryRun,
    [switch] $Force,
    [switch] $NoOverwrite,
    [switch] $SkipGitPull,
    [switch] $SkipGitPush
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
if (-not $FinishScript -and $config.ContainsKey('FinishScript')) { $FinishScript = [string]$config.FinishScript }

if (-not $FinishScript) {
    if (-not $ToolRoot) {
        Write-Host 'WorkbenchStateSync Finish skipped: no ToolRoot configured.' -ForegroundColor DarkGray
        Write-Host 'Clone MultiAgentWorkbenchStateSync, then set ToolRoot in Packages/WorkbenchStateSync/workbenchstatesync.config.psd1.' -ForegroundColor DarkGray
        exit 0
    }
    $FinishScript = Join-Path $ToolRoot 'Launchers\Finish.ps1'
}

$FinishScript = [IO.Path]::GetFullPath($FinishScript)
if (-not (Test-Path -LiteralPath $FinishScript)) {
    Write-Host "WorkbenchStateSync Finish skipped: script not found: $FinishScript" -ForegroundColor Yellow
    exit 0
}

Write-Host 'WorkbenchStateSync Finish (adapter)' -ForegroundColor Cyan
Write-Host "  tool:     $FinishScript"
Write-Host "  worktree: $RepoRoot"

$toolArgs = @{ WorktreeRoot = $RepoRoot }
if ($Force) { $toolArgs.Force = $true }
if ($NoOverwrite) { $toolArgs.NoOverwrite = $true }
if ($SkipGitPull) { $toolArgs.SkipGitPull = $true }
if ($SkipGitPush) { $toolArgs.SkipGitPush = $true }
if ($CommitMessage) { $toolArgs.CommitMessage = $CommitMessage }

if ($DryRun) {
    Write-Host "dry-run: $FinishScript -WorktreeRoot $RepoRoot" -ForegroundColor DarkGray
    exit 0
}

& $FinishScript @toolArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'WorkbenchStateSync Finish complete.' -ForegroundColor Green
