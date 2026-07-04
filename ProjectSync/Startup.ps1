#requires -Version 5.1
# Initial setup for the built-in ProjectSync tool: create Projects/projects.json
# from the tracked example so source projects can be registered for mirroring.
[CmdletBinding()]
param([switch] $Force)

$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $PackageRoot
$example = Join-Path $RepoRoot 'Projects\projects.example.json'
$target = Join-Path $RepoRoot 'Projects\projects.json'

Write-Host 'ProjectSync Startup (initial setup)' -ForegroundColor Cyan

if ((Test-Path -LiteralPath $target) -and -not $Force) {
    Write-Host "  projects.json already exists: $target (use -Force to overwrite)" -ForegroundColor DarkGray
}
else {
    Copy-Item -LiteralPath $example -Destination $target -Force
    Write-Host "  created: $target (from projects.example.json)" -ForegroundColor Green
    Write-Host '  Edit Projects/projects.json and fill local sourceRepoRoot paths.' -ForegroundColor Yellow
}
