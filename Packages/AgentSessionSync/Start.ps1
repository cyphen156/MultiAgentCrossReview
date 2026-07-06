#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $ToolRoot = '',
    [string] $StartScript = '',
    [switch] $DryRun,
    [switch] $Force,
    [switch] $SkipGitPull,
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
    if (-not $StartScript) { $StartScript = $defaults.StartScript }
    $resolvedRoot = Resolve-ToolRootPath $RepoRoot $ToolRoot
}
else {
    $entry = Resolve-SyncTool -RepoRoot $RepoRoot -ToolName $toolName -LegacyConfigPath $legacyConfig
    if (-not $entry) {
        Write-Host 'AgentSessionSync Start skipped: no ToolRoot registered and no Vault found.' -ForegroundColor DarkGray
        Write-Host 'Register with: .\Packages\AgentSessionSync\Register.ps1 -ToolRoot <AgentSessionVault path>' -ForegroundColor DarkGray
        exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
    }
    $resolvedRoot = $entry.ToolRoot
    if (-not $StartScript) { $StartScript = $entry.StartScript }
    $source = $entry.Source
}

$StartScript = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $StartScript))
if (-not (Test-Path -LiteralPath $StartScript)) {
    Write-Host "AgentSessionSync Start skipped: script not found: $StartScript" -ForegroundColor Yellow
    exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
}

Write-Host 'AgentSessionSync Start' -ForegroundColor Cyan
Write-Host "  source: $source"
Write-Host "  script: $StartScript"

if ($DryRun) {
    Write-Host "dry-run: $StartScript $($RemainingArguments -join ' ')" -ForegroundColor DarkGray
    exit 0
}

& $StartScript @RemainingArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'AgentSessionSync Start complete.' -ForegroundColor Green
