#requires -Version 5.1
# Initial setup for the AgentSessionSync connector: connect to (clone) or create
# the external AgentSessionSync tool repo, then write the connector config.
[CmdletBinding()]
param(
    [string] $ToolRoot = 'C:\Project\MultiAgent\AgentSessionSync',
    [string] $RepoUrl = 'https://github.com/cyphen156/AgentSessionSync.git',
    [ValidateSet('Connect', 'Create')] [string] $Mode = 'Connect'
)

$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $PackageRoot 'agentsessionsync.config.psd1'

Write-Host 'AgentSessionSync Startup (initial setup)' -ForegroundColor Cyan
Write-Host "  ToolRoot: $ToolRoot"

if (Test-Path -LiteralPath (Join-Path $ToolRoot '.git')) {
    Write-Host '  external tool already present -> connect' -ForegroundColor Green
}
elseif ($Mode -eq 'Create') {
    Write-Host "  create new local tool repo (git init): $ToolRoot"
    New-Item -ItemType Directory -Force -Path $ToolRoot | Out-Null
    & git init $ToolRoot | Out-Null
}
else {
    Write-Host "  connect to external repo (git clone): $RepoUrl"
    & git clone $RepoUrl $ToolRoot
    if ($LASTEXITCODE -ne 0) { throw "git clone failed: $RepoUrl" }
}

Set-Content -LiteralPath $ConfigPath -Encoding UTF8 -Value @(
    '@{'
    "    ToolRoot = '$ToolRoot'"
    "    StartScript = ''"
    "    FinishScript = ''"
    '}'
)
Write-Host "  wrote connector config: $ConfigPath" -ForegroundColor Green
Write-Host 'Startup complete. Set the session vault and agents in the external tool config at ToolRoot.' -ForegroundColor Green
