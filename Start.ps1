#requires -Version 5.1
[CmdletBinding()]
param(
    [switch] $DryRun,
    [switch] $Force,
    [switch] $SkipGitPull,
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
        Write-Host 'WorkbenchStateSync Start skipped: no local config.' -ForegroundColor DarkGray
        return $false
    }
    return $true
}

function Invoke-PackageStart([string] $PackageName, [string] $ScriptPath) {
    Write-Host ""
    Write-Host "== Start: $PackageName ==" -ForegroundColor Cyan

    $scriptArgs = @{}
    if ($DryRun) { $scriptArgs.DryRun = $true }
    if ($Force) { $scriptArgs.Force = $true }
    if ($SkipGitPull) { $scriptArgs.SkipGitPull = $true }

    & $ScriptPath @scriptArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$PackageName Start failed with exit code $LASTEXITCODE"
    }
}

Write-Host 'Workbench Start' -ForegroundColor Cyan
Write-Host "  packages: $PackagesRoot"
Write-Host "  excluded by default: $($DefaultExcludedPackages -join ', ')"

$packages = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory | Sort-Object Name)
$selected = @()
foreach ($package in $packages) {
    $startScript = Join-Path $package.FullName 'Start.ps1'
    if ((Test-Path -LiteralPath $startScript) -and (Test-SelectedPackage $package.Name) -and (Test-PackageConfigured $package.Name)) {
        $selected += [pscustomobject]@{ Name = $package.Name; Script = $startScript }
    }
}

if ($selected.Count -eq 0) {
    Write-Host 'No package Start.ps1 scripts selected.' -ForegroundColor Yellow
    exit 0
}

foreach ($item in $selected) {
    Invoke-PackageStart -PackageName $item.Name -ScriptPath $item.Script
}

Write-Host ""
Write-Host 'Workbench Start complete.' -ForegroundColor Green
