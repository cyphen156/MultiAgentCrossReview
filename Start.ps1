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

function New-Result([string] $Package, [string] $Action, [string] $Result, [string] $Reason, [int] $ExitCode) {
    [pscustomobject]@{
        Package = $Package
        Action = $Action
        Result = $Result
        Reason = $Reason
        ExitCode = $ExitCode
    }
}

# Membership = folder placement. Every Packages/<name>/ that has Start.ps1 is an
# external optional sync adapter and runs here. Packages/ProjectSync/ is a built-in
# one-way mirror that exposes Sync.ps1 (not Start.ps1), so this folder scan skips it
# ('no Start.ps1') and it is intentionally not part of this button.
$packages = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)

Write-Host 'Workbench Start' -ForegroundColor Cyan
Write-Host "  packages: $PackagesRoot"

$results = @()
foreach ($pkg in $packages) {
    $name = $pkg.Name
    if ($Include.Count -gt 0 -and $Include -notcontains $name) {
        $results += New-Result $name 'Start' 'SKIP' 'filtered by -Include' 0
        continue
    }
    if ($Exclude -contains $name) {
        $results += New-Result $name 'Start' 'SKIP' 'filtered by -Exclude' 0
        continue
    }
    $scriptPath = Join-Path $pkg.FullName 'Start.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $results += New-Result $name 'Start' 'SKIP' 'no Start.ps1' 0
        continue
    }

    Write-Host ""
    Write-Host "== Start: $name ==" -ForegroundColor Cyan

    $scriptArgs = @{}
    if ($DryRun) { $scriptArgs.DryRun = $true }
    if ($Force) { $scriptArgs.Force = $true }
    if ($SkipGitPull) { $scriptArgs.SkipGitPull = $true }

    try {
        $global:LASTEXITCODE = 0
        & $scriptPath @scriptArgs
        $code = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        if ($code -eq 200) { $results += New-Result $name 'Start' 'SKIP' 'not configured' 0 }
        elseif ($code -ne 0) { $results += New-Result $name 'Start' 'FAIL' "exit code $code" $code }
        else { $results += New-Result $name 'Start' 'OK' '' 0 }
    }
    catch {
        $results += New-Result $name 'Start' 'FAIL' $_.Exception.Message 1
    }
}

Write-Host ""
Write-Host 'Workbench Start summary' -ForegroundColor Cyan
$results | Format-Table Package, Action, Result, Reason -AutoSize

$worst = 0
foreach ($result in $results) {
    if ($result.ExitCode -ne 0) { $worst = 1 }
}

if ($worst -ne 0) {
    Write-Host 'Workbench Start completed with failures.' -ForegroundColor Red
    exit $worst
}

Write-Host 'Workbench Start complete.' -ForegroundColor Green
