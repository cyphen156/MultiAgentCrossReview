#requires -Version 5.1
[CmdletBinding()]
param(
    [switch] $DryRun,
    [switch] $Force,
    [switch] $NoOverwrite,
    [switch] $SkipGitPull,
    [switch] $SkipGitPush,
    [string] $CommitMessage = '',
    [string[]] $Include = @(),
    [string[]] $Exclude = @()
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagesRoot = Join-Path $RepoRoot 'Packages'
$DefaultExcludedPackages = @('ProjectSync')

function Test-SelectedPackage([string] $Name) {
    if ($Include.Count -gt 0 -and $Include -notcontains $Name) { return $false }
    if ($Exclude -contains $Name) { return $false }
    if ($DefaultExcludedPackages -contains $Name -and $Include -notcontains $Name) { return $false }
    return $true
}

function Test-PackageConfigured([string] $Name) {
    if ($Include -contains $Name) { return $true }
    if ($Name -eq 'WorkbenchStateSync') {
        $candidates = @(
            (Join-Path $RepoRoot 'Packages\WorkbenchStateSync\workbenchstatesync.config.psd1'),
            (Join-Path $RepoRoot 'WorkbenchStateSync.local.psd1')
        )
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) { return $true }
        }
        Write-Host 'WorkbenchStateSync Finish skipped: no local config.' -ForegroundColor DarkGray
        return $false
    }
    return $true
}

function Invoke-PackageFinish([string] $PackageName, [string] $ScriptPath) {
    Write-Host ""
    Write-Host "== Finish: $PackageName ==" -ForegroundColor Cyan

    $scriptArgs = @{}
    if ($DryRun) { $scriptArgs.DryRun = $true }
    if ($Force) { $scriptArgs.Force = $true }
    if ($NoOverwrite) { $scriptArgs.NoOverwrite = $true }
    if ($SkipGitPull) { $scriptArgs.SkipGitPull = $true }
    if ($SkipGitPush) { $scriptArgs.SkipGitPush = $true }
    if ($CommitMessage) { $scriptArgs.CommitMessage = $CommitMessage }

    & $ScriptPath @scriptArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$PackageName Finish failed with exit code $LASTEXITCODE"
    }
}

Write-Host 'Workbench Finish' -ForegroundColor Cyan
Write-Host "  packages: $PackagesRoot"
Write-Host "  excluded by default: $($DefaultExcludedPackages -join ', ')"

$packages = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory | Sort-Object Name)
$selected = @()
foreach ($package in $packages) {
    $finishScript = Join-Path $package.FullName 'Finish.ps1'
    if ((Test-Path -LiteralPath $finishScript) -and (Test-SelectedPackage $package.Name) -and (Test-PackageConfigured $package.Name)) {
        $selected += [pscustomobject]@{ Name = $package.Name; Script = $finishScript }
    }
}

if ($selected.Count -eq 0) {
    Write-Host 'No package Finish.ps1 scripts selected.' -ForegroundColor Yellow
    exit 0
}

foreach ($item in $selected) {
    Invoke-PackageFinish -PackageName $item.Name -ScriptPath $item.Script
}

Write-Host ""
Write-Host 'Workbench Finish complete.' -ForegroundColor Green
