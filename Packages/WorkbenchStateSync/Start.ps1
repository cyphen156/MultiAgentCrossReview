#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $VaultRoot = '',
    [string] $WorktreeRoot = '',
    [switch] $Force,
    [switch] $DryRun,
    [switch] $SkipGitPull
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)
$WorkbenchStateSyncScript = Join-Path $PackageRoot 'workbenchstatesync.ps1'

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

function Invoke-Git([string] $Repo, [string[]] $GitArgs) {
    $safeRepo = $Repo.Replace('\', '/')
    & git -c "safe.directory=$safeRepo" -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed in $Repo"
    }
}

$LocalConfig = Import-WorkbenchStateSyncConfig
if (-not $VaultRoot -and $LocalConfig.ContainsKey('VaultRoot')) { $VaultRoot = [string]$LocalConfig.VaultRoot }
if (-not $WorktreeRoot -and $LocalConfig.ContainsKey('WorktreeRoot')) { $WorktreeRoot = [string]$LocalConfig.WorktreeRoot }
if (-not $WorktreeRoot) { $WorktreeRoot = $RepoRoot }
if (-not $VaultRoot) { throw 'VaultRoot is required. Create ignored Packages/WorkbenchStateSync/workbenchstatesync.config.psd1 or pass -VaultRoot.' }

$VaultRoot = [IO.Path]::GetFullPath($VaultRoot).TrimEnd('\', '/')
$WorktreeRoot = [IO.Path]::GetFullPath($WorktreeRoot).TrimEnd('\', '/')

Write-Host 'WorkbenchStateSync Start' -ForegroundColor Cyan
Write-Host "  vault:   $VaultRoot"
Write-Host "  worktree: $WorktreeRoot"

if (-not $DryRun -and -not $SkipGitPull) {
    Invoke-Git -Repo $VaultRoot -GitArgs @('pull', '--ff-only')
}
elseif ($DryRun -and -not $SkipGitPull) {
    Write-Host 'dry-run: git pull --ff-only' -ForegroundColor DarkGray
}

& $WorkbenchStateSyncScript -Direction Pull -VaultRoot $VaultRoot -WorktreeRoot $WorktreeRoot -Force:$Force -DryRun:$DryRun
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'WorkbenchStateSync Start complete.' -ForegroundColor Green
