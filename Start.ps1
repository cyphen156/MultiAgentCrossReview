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

# Declared here and again in Finish.ps1 on purpose. The workbench body stays in
# these two entry points and introduces no shared module for it.
enum GateStatus {
    Success
    Failure
    Skipped
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagesRoot = Join-Path $RepoRoot 'Packages'

function New-Result([string] $Package, [GateStatus] $Status, [string] $Reason) {
    [pscustomobject]@{
        Package = $Package
        Status = $Status
        Reason = $Reason
    }
}

# Membership = folder placement. Every Packages/<name>/ that has Start.ps1 is an
# external optional sync adapter and runs here. Packages/ProjectSync/ is a built-in
# one-way mirror that exposes Sync.ps1 (not Start.ps1), so this folder scan skips it
# ('no Start.ps1') and it is intentionally not part of this button.
# AgentSessionSync opens the registered agent apps. Run it only after every other
# Start adapter has finished so agents never observe workbench state changing
# underneath an already-started session.
$packages = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object @{ Expression = { if ($_.Name -eq 'AgentSessionSync') { 1 } else { 0 } } }, Name)

Write-Host 'Workbench Start' -ForegroundColor Cyan
Write-Host "  packages: $PackagesRoot"

$results = @()
foreach ($pkg in $packages) {
    $name = $pkg.Name
    if ($Include.Count -gt 0 -and $Include -notcontains $name) {
        $results += New-Result $name Skipped 'filtered by -Include'
        continue
    }
    if ($Exclude -contains $name) {
        $results += New-Result $name Skipped 'filtered by -Exclude'
        continue
    }
    $scriptPath = Join-Path $pkg.FullName 'Start.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $results += New-Result $name Skipped 'no Start.ps1'
        continue
    }

    Write-Host ""
    Write-Host "== Start: $name ==" -ForegroundColor Cyan

    $scriptArgs = @{}
    if ($DryRun) { $scriptArgs.DryRun = $true }
    if ($Force) { $scriptArgs.Force = $true }
    if ($SkipGitPull) { $scriptArgs.SkipGitPull = $true }

    # Adapter output goes straight to the console; it is not captured here.
    # A failing tool never stops the remaining tools. Each tool owns its own
    # rollback, so this body adds no preflight and no cross-tool transaction.
    try {
        $global:LASTEXITCODE = 0
        & $scriptPath @scriptArgs
        $code = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        if ($code -eq 200) { $results += New-Result $name Skipped 'not configured' }
        elseif ($code -ne 0) { $results += New-Result $name Failure "exit code $code" }
        else { $results += New-Result $name Success '' }
    }
    catch {
        $results += New-Result $name Failure $_.Exception.Message
    }
}

# Any failure fails the run. Otherwise any executed success succeeds it.
# Nothing but skips reports Skipped.
$overall = [GateStatus]::Skipped
if (@($results | Where-Object { $_.Status -eq [GateStatus]::Failure }).Count -gt 0) {
    $overall = [GateStatus]::Failure
}
elseif (@($results | Where-Object { $_.Status -eq [GateStatus]::Success }).Count -gt 0) {
    $overall = [GateStatus]::Success
}

Write-Host ""
Write-Host 'Workbench Start summary' -ForegroundColor Cyan
foreach ($result in $results) {
    $color = switch ($result.Status) {
        ([GateStatus]::Success) { 'Green' }
        ([GateStatus]::Failure) { 'Red' }
        default { 'DarkGray' }
    }
    $line = "  {0,-20} : {1}" -f $result.Package, $result.Status
    if ($result.Reason) { $line = "$line : $($result.Reason)" }
    Write-Host $line -ForegroundColor $color
}

Write-Host ""
switch ($overall) {
    ([GateStatus]::Failure) {
        Write-Host 'Overall : Failure' -ForegroundColor Red
        exit 1
    }
    ([GateStatus]::Success) {
        Write-Host 'Overall : Success' -ForegroundColor Green
        exit 0
    }
    default {
        Write-Host 'Overall : Skipped' -ForegroundColor DarkGray
        exit 0
    }
}
