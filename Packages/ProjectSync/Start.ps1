#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $Project = '',
    [ValidateSet('', 'Claud', 'Codex', 'All')]
    [string] $ResetEdit = '',
    [switch] $DryRun,
    [switch] $Force,
    [switch] $SkipGitPull
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)
$SyncScript = Join-Path $RepoRoot 'sync.ps1'

if (-not (Test-Path -LiteralPath $SyncScript)) {
    throw "sync.ps1 not found: $SyncScript"
}

$scriptArgs = @()
if ($Project) { $scriptArgs += @('-Project', $Project) }
if ($ResetEdit) { $scriptArgs += @('-ResetEdit', $ResetEdit) }

Write-Host 'ProjectSync Start' -ForegroundColor Cyan
Write-Host "  script: $SyncScript"

if ($DryRun) {
    Write-Host "dry-run: $SyncScript $($scriptArgs -join ' ')" -ForegroundColor DarkGray
    exit 0
}

& $SyncScript @scriptArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'ProjectSync Start complete.' -ForegroundColor Green
