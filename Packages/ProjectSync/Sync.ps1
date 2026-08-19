#requires -Version 5.1
[CmdletBinding()]
# 이 래퍼의 파라미터는 root sync.ps1 의 파라미터와 정확히 일치해야 한다.
# 예전에는 -Force / -SkipGitPull 이 선언만 돼 있고 하위로 전달되지 않아, 지정해도
# 조용히 무시됐다. 하위가 지원하지 않는 스위치는 선언하지 않는다.
param(
    [string] $Project = '',
    [ValidateSet('', 'Claud', 'Codex', 'All')]
    [string] $ResetEdit = '',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)
$SyncScript = Join-Path $RepoRoot 'sync.ps1'

if (-not (Test-Path -LiteralPath $SyncScript)) {
    throw "sync.ps1 not found: $SyncScript"
}

$scriptArgs = @{}
if ($Project) { $scriptArgs['Project'] = $Project }
if ($ResetEdit) { $scriptArgs['ResetEdit'] = $ResetEdit }

Write-Host 'ProjectSync Sync' -ForegroundColor Cyan
Write-Host "  script: $SyncScript"

if ($DryRun) {
    $argText = ($scriptArgs.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    Write-Host "dry-run: $SyncScript $argText" -ForegroundColor DarkGray
    exit 0
}

& $SyncScript @scriptArgs

Write-Host 'ProjectSync Sync complete.' -ForegroundColor Green
