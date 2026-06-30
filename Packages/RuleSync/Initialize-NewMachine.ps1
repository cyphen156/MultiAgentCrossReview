#requires -Version 5.1
<#
  Initialize-NewMachine.ps1 - cold bootstrap for a fresh machine.

  Assumes the public MultiAgentCrossReview repo is already cloned and you run this
  from inside it. Creates the machine-local files that are intentionally NOT synced
  (paths differ per machine), then materializes private rules.

  What it does:
    1. Clone the private rules vault to -RulesVaultRoot (if missing).
    2. Write ignored Packages/RuleSync/rulesync.config.psd1 (VaultRoot).
    3. Write ignored Projects/projects.json from projects.example.json
       (only if -SourceRepoRoot and -ProjectName are given).
    4. Run RuleSync Start.ps1 (pull rules vault -> worktree).
    5. Optionally run sync.ps1 to rebuild the baseline mirror (-RunSync).

  Session (conversation JSONL) sync is a separate tool: clone your private session
  vault and run its own Initialize-AgentSessionSync.ps1. Not handled here.

  Usage:
    .\Packages\RuleSync\Initialize-NewMachine.ps1 `
        -RulesVaultUrl  'https://github.com/<you>/<private-rules-vault>.git' `
        -RulesVaultRoot 'C:\<your>\RulesVault' `
        -SourceRepoRoot 'C:\Path\To\YourProject' `
        -ProjectName    'YourProject' `
        -RunSync

    Add -DryRun to preview every step without touching anything.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RulesVaultUrl,
    [Parameter(Mandatory)] [string] $RulesVaultRoot,
    [string] $SourceRepoRoot = '',
    [string] $ProjectName = '',
    [string] $EngineSubdir = '',
    [switch] $RunSync,
    [switch] $Force,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)

function Step([string] $m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Invoke-Step([string] $desc, [scriptblock] $action) {
    if ($DryRun) { Write-Host "[dry-run] $desc" -ForegroundColor DarkGray; return }
    Step $desc
    & $action
}

Write-Host "Initialize-NewMachine" -ForegroundColor Cyan
Write-Host "  repo:        $RepoRoot"
Write-Host "  rules vault: $RulesVaultRoot"

# 1) Clone the private rules vault.
if (Test-Path -LiteralPath $RulesVaultRoot) {
    Write-Host "rules vault already present, skipping clone: $RulesVaultRoot" -ForegroundColor DarkGray
}
else {
    Invoke-Step "clone rules vault -> $RulesVaultRoot" {
        & git clone $RulesVaultUrl $RulesVaultRoot
        if ($LASTEXITCODE -ne 0) { throw "git clone failed: $RulesVaultUrl" }
    }
}

# 2) Write ignored rulesync.config.psd1.
$cfg = Join-Path $PackageRoot 'rulesync.config.psd1'
if ((Test-Path -LiteralPath $cfg) -and -not $Force) {
    Write-Host "rulesync.config.psd1 exists, keeping it (use -Force to overwrite)" -ForegroundColor DarkGray
}
else {
    Invoke-Step "write rulesync.config.psd1 (VaultRoot=$RulesVaultRoot)" {
        $body = "@{`r`n    VaultRoot = '$RulesVaultRoot'`r`n    WorktreeRoot = ''`r`n}`r`n"
        [IO.File]::WriteAllText($cfg, $body, [Text.UTF8Encoding]::new($false))
    }
}

# 3) Write ignored Projects/projects.json from the example.
$projectsJson = Join-Path $RepoRoot 'Projects\projects.json'
if ((Test-Path -LiteralPath $projectsJson) -and -not $Force) {
    Write-Host "Projects/projects.json exists, keeping it" -ForegroundColor DarkGray
}
elseif ($SourceRepoRoot -and $ProjectName) {
    Invoke-Step "write Projects/projects.json (name=$ProjectName, source=$SourceRepoRoot)" {
        $sub = if ($EngineSubdir) { $EngineSubdir } else { $ProjectName }
        $obj = @{ projects = @(@{ name = $ProjectName; sourceRepoRoot = $SourceRepoRoot; engineSubdir = $sub }) }
        $json = ($obj | ConvertTo-Json -Depth 6)
        [IO.File]::WriteAllText($projectsJson, $json, [Text.UTF8Encoding]::new($false))
    }
}
else {
    Write-Host "Projects/projects.json: pass -SourceRepoRoot and -ProjectName to generate it, or copy projects.example.json manually." -ForegroundColor Yellow
}

# 4) Pull private rules into the worktree.
Invoke-Step "RuleSync Start (pull rules vault -> worktree)" {
    & (Join-Path $PackageRoot 'Start.ps1')
    if ($LASTEXITCODE -ne 0) { throw "RuleSync Start failed" }
}

# 5) Optional baseline rebuild (needs the source project present at -SourceRepoRoot).
if ($RunSync) {
    Invoke-Step "sync.ps1 (rebuild baseline/edit mirror)" {
        & (Join-Path $RepoRoot 'sync.ps1')
        if ($LASTEXITCODE -ne 0) { throw "sync.ps1 failed" }
    }
}

Write-Host "New-machine bootstrap complete." -ForegroundColor Green
Write-Host "Session sync is separate: clone your private session vault and run its Initialize-AgentSessionSync.ps1." -ForegroundColor DarkGray
$global:LASTEXITCODE = 0
