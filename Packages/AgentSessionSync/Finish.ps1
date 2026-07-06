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
    [switch] $SkipGitPush,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $RemainingArguments
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagesRoot = Split-Path -Parent $PackageRoot
$RepoRoot = Split-Path -Parent $PackagesRoot
. (Join-Path $PackagesRoot 'SyncToolRegistry.ps1')

$toolName = 'AgentSessionSync'
$legacyConfig = Join-Path $PackageRoot 'agentsessionsync.config.psd1'
$source = 'param'

if ($ToolRoot) {
    $defaults = Get-SyncToolDefaults $toolName
    if (-not $FinishScript) { $FinishScript = $defaults.FinishScript }
    $resolvedRoot = Resolve-ToolRootPath $RepoRoot $ToolRoot
}
else {
    $entry = Resolve-SyncTool -RepoRoot $RepoRoot -ToolName $toolName -LegacyConfigPath $legacyConfig
    if (-not $entry) {
        Write-Host 'AgentSessionSync Finish skipped: no ToolRoot registered and no Vault found.' -ForegroundColor DarkGray
        Write-Host 'Register with: .\Packages\AgentSessionSync\Register.ps1 -ToolRoot <AgentSessionVault path>' -ForegroundColor DarkGray
        exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
    }
    $resolvedRoot = $entry.ToolRoot
    if (-not $FinishScript) { $FinishScript = $entry.FinishScript }
    $source = $entry.Source
}

$FinishScript = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $FinishScript))
if (-not (Test-Path -LiteralPath $FinishScript)) {
    Write-Host "AgentSessionSync Finish skipped: script not found: $FinishScript" -ForegroundColor Yellow
    exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
}

Write-Host 'AgentSessionSync Finish' -ForegroundColor Cyan
Write-Host "  source: $source"
Write-Host "  script: $FinishScript"

if ($DryRun) {
    Write-Host "dry-run: $FinishScript $($RemainingArguments -join ' ')" -ForegroundColor DarkGray
    exit 0
}

& $FinishScript @RemainingArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'AgentSessionSync Finish complete.' -ForegroundColor Green
