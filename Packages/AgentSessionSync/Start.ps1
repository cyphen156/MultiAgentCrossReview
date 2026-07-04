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
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)

function Import-AgentSessionSyncConfig {
    $candidates = @(
        (Join-Path $PackageRoot 'agentsessionsync.config.psd1'),
        (Join-Path $RepoRoot 'AgentSessionSync.local.psd1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return Import-PowerShellDataFile -LiteralPath $candidate
        }
    }

    return @{}
}

$config = Import-AgentSessionSyncConfig
if (-not $ToolRoot -and $config.ContainsKey('ToolRoot')) { $ToolRoot = [string]$config.ToolRoot }
if (-not $StartScript -and $config.ContainsKey('StartScript')) { $StartScript = [string]$config.StartScript }

if (-not $StartScript) {
    if (-not $ToolRoot) {
        Write-Host 'AgentSessionSync Start skipped: no ToolRoot configured.' -ForegroundColor DarkGray
        Write-Host 'Create ignored Packages/AgentSessionSync/agentsessionsync.config.psd1 to enable it.' -ForegroundColor DarkGray
        exit 0
    }
    $StartScript = Join-Path $ToolRoot 'Start.ps1'
}

$StartScript = [IO.Path]::GetFullPath($StartScript)
if (-not (Test-Path -LiteralPath $StartScript)) {
    Write-Host "AgentSessionSync Start skipped: script not found: $StartScript" -ForegroundColor Yellow
    exit 0
}

Write-Host 'AgentSessionSync Start' -ForegroundColor Cyan
Write-Host "  script: $StartScript"

if ($DryRun) {
    Write-Host "dry-run: $StartScript $($RemainingArguments -join ' ')" -ForegroundColor DarkGray
    exit 0
}

& $StartScript @RemainingArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'AgentSessionSync Start complete.' -ForegroundColor Green
