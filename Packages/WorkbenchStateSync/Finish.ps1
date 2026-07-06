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
$PackagesRoot = Split-Path -Parent $PackageRoot
$RepoRoot = Split-Path -Parent $PackagesRoot
. (Join-Path $PackagesRoot 'SyncToolRegistry.ps1')

$toolName = 'WorkbenchStateSync'
$legacyConfig = Join-Path $PackageRoot 'workbenchstatesync.config.psd1'
$source = 'param'

if ($ToolRoot) {
    $defaults = Get-SyncToolDefaults $toolName
    if (-not $FinishScript) { $FinishScript = $defaults.FinishScript }
    $resolvedRoot = Resolve-ToolRootPath $RepoRoot $ToolRoot
}
else {
    $entry = Resolve-SyncTool -RepoRoot $RepoRoot -ToolName $toolName -LegacyConfigPath $legacyConfig
    if (-not $entry) {
        Write-Host 'WorkbenchStateSync Finish skipped: no ToolRoot registered and no Vault found.' -ForegroundColor DarkGray
        Write-Host 'Register with: .\Packages\WorkbenchStateSync\Register.ps1 -ToolRoot <MultiAgentWorkbenchStateVault path>' -ForegroundColor DarkGray
        exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
    }
    $resolvedRoot = $entry.ToolRoot
    if (-not $FinishScript) { $FinishScript = $entry.FinishScript }
    $source = $entry.Source
}

$FinishScript = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $FinishScript))
if (-not (Test-Path -LiteralPath $FinishScript)) {
    Write-Host "WorkbenchStateSync Finish skipped: script not found: $FinishScript" -ForegroundColor Yellow
    exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
}

Write-Host 'WorkbenchStateSync Finish (adapter)' -ForegroundColor Cyan
Write-Host "  source:   $source"
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
