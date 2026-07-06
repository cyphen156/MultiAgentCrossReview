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
if (-not $FinishScript -and $config.ContainsKey('FinishScript')) { $FinishScript = [string]$config.FinishScript }

if (-not $FinishScript) {
    if (-not $ToolRoot) {
        Write-Host 'AgentSessionSync Finish skipped: no ToolRoot configured.' -ForegroundColor DarkGray
        Write-Host 'Create ignored Packages/AgentSessionSync/agentsessionsync.config.psd1 to enable it.' -ForegroundColor DarkGray
        exit 0
    }
    $FinishScript = Join-Path $ToolRoot 'Launchers\Finish.ps1'
}

$FinishScript = [IO.Path]::GetFullPath($FinishScript)
if (-not (Test-Path -LiteralPath $FinishScript)) {
    Write-Host "AgentSessionSync Finish skipped: script not found: $FinishScript" -ForegroundColor Yellow
    exit 0
}

Write-Host 'AgentSessionSync Finish' -ForegroundColor Cyan
Write-Host "  script: $FinishScript"

if ($DryRun) {
    Write-Host "dry-run: $FinishScript $($RemainingArguments -join ' ')" -ForegroundColor DarkGray
    exit 0
}

& $FinishScript @RemainingArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'AgentSessionSync Finish complete.' -ForegroundColor Green
