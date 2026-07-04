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
$ManifestPath = Join-Path $RepoRoot 'Packages\aggregate.psd1'

function Resolve-RepoPath([string] $Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Import-AggregateManifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Aggregate manifest not found: $ManifestPath"
    }
    return Import-PowerShellDataFile -LiteralPath $ManifestPath
}

function Test-ManifestSelection([string] $Name) {
    if ($Include.Count -gt 0 -and $Include -notcontains $Name) { return $false }
    if ($Exclude -contains $Name) { return $false }
    return $true
}

function Test-Configured([hashtable] $Package, [ref] $Reason) {
    if (-not $Package.ContainsKey('ConfigAny')) { return $true }
    foreach ($relativeConfig in @($Package.ConfigAny)) {
        $configPath = Resolve-RepoPath $relativeConfig
        if (Test-Path -LiteralPath $configPath) { return $true }
    }
    $Reason.Value = 'no local config'
    return $false
}

function New-Result([string] $Package, [string] $Action, [string] $Result, [string] $Reason, [int] $ExitCode) {
    [pscustomobject]@{
        Package = $Package
        Action = $Action
        Result = $Result
        Reason = $Reason
        ExitCode = $ExitCode
    }
}

function Invoke-PackageStart([hashtable] $Package) {
    $name = [string]$Package.Name
    $scriptName = [string]$Package.StartScript
    $scriptPath = Resolve-RepoPath (Join-Path "Packages\$name" $scriptName)

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        return New-Result $name 'Start' 'SKIP' "script not found: $scriptPath" 0
    }

    $reason = ''
    if (-not (Test-Configured $Package ([ref]$reason))) {
        return New-Result $name 'Start' 'SKIP' $reason 0
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
        $code = if ($LASTEXITCODE -ne $null) { [int]$LASTEXITCODE } else { 0 }
        if ($code -ne 0) { return New-Result $name 'Start' 'FAIL' "exit code $code" $code }
        return New-Result $name 'Start' 'OK' '' 0
    }
    catch {
        return New-Result $name 'Start' 'FAIL' $_.Exception.Message 1
    }
}

$manifest = Import-AggregateManifest
$packages = @($manifest.Packages | ForEach-Object { [hashtable]$_ })

Write-Host 'Workbench Start' -ForegroundColor Cyan
Write-Host "  manifest: $ManifestPath"

$results = @()
foreach ($package in $packages) {
    $name = [string]$package.Name
    if (-not (Test-ManifestSelection $name)) {
        $results += New-Result $name 'Start' 'SKIP' 'filtered by Include/Exclude' 0
        continue
    }
    $results += Invoke-PackageStart $package
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
