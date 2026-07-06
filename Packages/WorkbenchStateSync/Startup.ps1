#requires -Version 5.1
# Initial setup for the WorkbenchStateSync connector.
#   -Mode Register (default): register an existing MultiAgentWorkbenchStateVault folder.
#   -Mode Create:             clone (RepoUrl) or git-init a new Vault at VaultRoot, then register.
# Either way the result is an entry in UserSettings/sync-tools.json (local, gitignored).
# The public MultiAgentWorkbenchStateSync repo is only the example template; VaultRoot should
# point at your private MultiAgentWorkbenchStateVault.
[CmdletBinding()]
param(
    [ValidateSet('Register', 'Create')] [string] $Mode = 'Register',
    [Parameter(Mandatory)][string] $VaultRoot,
    [string] $RepoUrl = 'https://github.com/cyphen156/MultiAgentWorkbenchStateVault.git',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagesRoot = Split-Path -Parent $PackageRoot
$RepoRoot = Split-Path -Parent $PackagesRoot
. (Join-Path $PackagesRoot 'SyncToolRegistry.ps1')

$toolName = 'WorkbenchStateSync'
$defaults = Get-SyncToolDefaults $toolName
$abs = Resolve-ToolRootPath $RepoRoot $VaultRoot

Write-Host "WorkbenchStateSync Startup ($Mode)" -ForegroundColor Cyan
Write-Host "  VaultRoot: $abs"

if ($Mode -eq 'Create') {
    if (Test-Path -LiteralPath (Join-Path $abs '.git')) {
        Write-Host '  vault already present -> registering existing' -ForegroundColor Green
    }
    elseif ($DryRun) {
        Write-Host "  dry-run: would git clone $RepoUrl -> $abs" -ForegroundColor DarkGray
    }
    else {
        Write-Host "  git clone $RepoUrl -> $abs"
        & git clone $RepoUrl $abs
        if ($LASTEXITCODE -ne 0) { throw "git clone failed: $RepoUrl" }
    }
}

$canValidate = (Test-Path -LiteralPath $abs)
if ($canValidate) {
    foreach ($req in @($defaults.StartScript, $defaults.FinishScript)) {
        $p = Join-Path $abs $req
        if (-not (Test-Path -LiteralPath $p)) {
            if ($Mode -eq 'Create' -and $DryRun) { continue }
            throw "Required launcher missing: $p"
        }
    }
}

if ($DryRun) {
    Write-Host "dry-run: would register $toolName -> '$VaultRoot' in $(Get-SyncRegistryPath $RepoRoot)" -ForegroundColor DarkGray
    exit 0
}

$path = Write-SyncToolRegistration -RepoRoot $RepoRoot -ToolName $toolName -ToolRoot $VaultRoot
Write-Host "Registered $toolName -> $path" -ForegroundColor Green
Write-Host 'Startup complete. Set the state-repo target (VaultRoot) in the tool config at that Vault.' -ForegroundColor Green
