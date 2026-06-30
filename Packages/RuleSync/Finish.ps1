#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $VaultRoot = '',
    [string] $WorktreeRoot = '',
    [string] $CommitMessage = 'rulesync: update private rules',
    [switch] $Force,
    [switch] $NoOverwrite,
    [switch] $DryRun,
    [switch] $SkipGitPull,
    [switch] $SkipGitPush
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)
$RuleSyncScript = Join-Path $PackageRoot 'rulesync.ps1'

function Import-RuleSyncConfig {
    $candidates = @(
        (Join-Path $PackageRoot 'rulesync.config.psd1'),
        (Join-Path $RepoRoot 'RuleSync.local.psd1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return Import-PowerShellDataFile -LiteralPath $candidate
        }
    }

    return @{}
}

function Invoke-Git([string] $Repo, [string[]] $GitArgs) {
    & git -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed in $Repo"
    }
}

function Get-GitCurrentBranch([string] $Repo) {
    $branch = (& git -C $Repo branch --show-current)
    if ($LASTEXITCODE -ne 0 -or -not $branch) {
        throw "Unable to resolve current branch in $Repo"
    }
    return $branch.Trim()
}

function Get-GitPorcelain([string] $Repo) {
    $status = @(& git -C $Repo status --porcelain -- UserSettings Projects)
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed in $Repo"
    }
    return @($status | Where-Object { $_ -notmatch '\.bak-' })
}

function Get-RelativePath([string] $Base, [string] $Path) {
    $baseUri = [Uri](([IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + '\'))
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Add-RulePaths([string] $Repo) {
    $files = @()
    $userSettings = Join-Path $Repo 'UserSettings'
    if (Test-Path -LiteralPath $userSettings) {
        $files += Get-ChildItem -LiteralPath $userSettings -Filter '*.md' -Recurse -File |
            Where-Object { $_.Name -notmatch '\.bak-' }
    }

    $projects = Join-Path $Repo 'Projects'
    if (Test-Path -LiteralPath $projects) {
        $files += Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $rule = Join-Path $_.FullName 'RULES.md'
                if (Test-Path -LiteralPath $rule) { Get-Item -LiteralPath $rule }
            }
    }

    $relativePaths = @($files | ForEach-Object { Get-RelativePath $Repo $_.FullName })
    if ($relativePaths.Count -eq 0) { return }
    Invoke-Git -Repo $Repo -GitArgs (@('add', '--') + $relativePaths)
}

$LocalConfig = Import-RuleSyncConfig
if (-not $VaultRoot -and $LocalConfig.ContainsKey('VaultRoot')) { $VaultRoot = [string]$LocalConfig.VaultRoot }
if (-not $WorktreeRoot -and $LocalConfig.ContainsKey('WorktreeRoot')) { $WorktreeRoot = [string]$LocalConfig.WorktreeRoot }
if (-not $WorktreeRoot) { $WorktreeRoot = $RepoRoot }
if (-not $VaultRoot) { throw 'VaultRoot is required. Create ignored Packages/RuleSync/rulesync.config.psd1 or pass -VaultRoot.' }

$VaultRoot = [IO.Path]::GetFullPath($VaultRoot).TrimEnd('\', '/')
$WorktreeRoot = [IO.Path]::GetFullPath($WorktreeRoot).TrimEnd('\', '/')

Write-Host 'RuleSync Finish' -ForegroundColor Cyan
Write-Host "  vault:   $VaultRoot"
Write-Host "  worktree: $WorktreeRoot"

if (-not $DryRun -and -not $SkipGitPull) {
    Invoke-Git -Repo $VaultRoot -GitArgs @('pull', '--ff-only')
}
elseif ($DryRun -and -not $SkipGitPull) {
    Write-Host 'dry-run: git pull --ff-only' -ForegroundColor DarkGray
}

$overwrite = (-not $NoOverwrite) -or $Force
& $RuleSyncScript -Direction Push -VaultRoot $VaultRoot -WorktreeRoot $WorktreeRoot -Force:$overwrite -DryRun:$DryRun
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($DryRun) {
    Write-Host 'dry-run: git add/commit/push skipped' -ForegroundColor DarkGray
    Write-Host 'RuleSync Finish dry-run complete.' -ForegroundColor Green
    exit 0
}

$changes = @(Get-GitPorcelain $VaultRoot)
if ($changes.Count -gt 0) {
    Add-RulePaths $VaultRoot
    Invoke-Git -Repo $VaultRoot -GitArgs @('commit', '-m', $CommitMessage)
}
else {
    Write-Host 'No private rule changes to commit.' -ForegroundColor DarkGray
}

if (-not $SkipGitPush) {
    $branch = Get-GitCurrentBranch $VaultRoot
    Invoke-Git -Repo $VaultRoot -GitArgs @('push', 'origin', $branch)
}

Write-Host 'RuleSync Finish complete.' -ForegroundColor Green
