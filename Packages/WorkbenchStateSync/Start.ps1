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
$PackagesRoot = Split-Path -Parent $PackageRoot
$RepoRoot = Split-Path -Parent $PackagesRoot
. (Join-Path $PackagesRoot 'SyncToolRegistry.ps1')

$toolName = 'WorkbenchStateSync'
$legacyConfig = Join-Path $PackageRoot 'workbenchstatesync.config.psd1'
$source = 'param'

if ($ToolRoot) {
    $defaults = Get-SyncToolDefaults $toolName
    if (-not $StartScript) { $StartScript = $defaults.StartScript }
    $resolvedRoot = Resolve-ToolRootPath $RepoRoot $ToolRoot
}
else {
    $entry = Resolve-SyncTool -RepoRoot $RepoRoot -ToolName $toolName -LegacyConfigPath $legacyConfig
    if (-not $entry) {
        Write-Host 'WorkbenchStateSync Start skipped: no ToolRoot registered and no Vault found.' -ForegroundColor DarkGray
        Write-Host 'Register with: .\Packages\WorkbenchStateSync\Register.ps1 -ToolRoot <MultiAgentWorkbenchStateVault path>' -ForegroundColor DarkGray
        exit 200  # skip sentinel: root reports SKIP, not OK/FAIL
    }
    $resolvedRoot = $entry.ToolRoot
    if (-not $StartScript) { $StartScript = $entry.StartScript }
    $source = $entry.Source
}

$StartScript = Resolve-ToolScriptPath -ToolRoot $resolvedRoot -ScriptPath $StartScript -Label 'WorkbenchStateSync StartScript'
if (-not (Test-Path -LiteralPath $StartScript)) {
    throw "Registered WorkbenchStateSync StartScript is missing: $StartScript"
}

Write-Host 'WorkbenchStateSync Start (adapter)' -ForegroundColor Cyan
Write-Host "  source:   $source"
Write-Host "  tool:     $StartScript"
Write-Host "  worktree: $RepoRoot"

# ToolRoot is the self-contained Vault, so VaultRoot = that Vault root. Injecting it
# here means the Vault needs no separate workbenchstatesync.config.psd1.
$toolArgs = @{ VaultRoot = $resolvedRoot; WorktreeRoot = $RepoRoot }
if ($Force) { $toolArgs.Force = $true }
if ($SkipGitPull) { $toolArgs.SkipGitPull = $true }

if ($DryRun) {
    Write-Host "dry-run: $StartScript -VaultRoot $resolvedRoot -WorktreeRoot $RepoRoot" -ForegroundColor DarkGray
    exit 0
}

& $StartScript @toolArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'WorkbenchStateSync Start complete.' -ForegroundColor Green
