#requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent $PSScriptRoot
$packagesRoot = Split-Path -Parent $packageRoot
. (Join-Path $packagesRoot 'SyncToolRegistry.ps1')

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('AgentSessionConnector-' + [guid]::NewGuid().ToString('N'))
$passed = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERT FAILED [#$($script:passed + 1)]: $Message" }
    $script:passed++
}
function Write-TestScript([string]$Path, [string]$Marker) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [IO.File]::WriteAllText($Path, "[IO.File]::WriteAllText('$($Marker.Replace("'", "''"))','OK')`n", (New-Object Text.UTF8Encoding($false)))
}

try {
    $fakeWorkbench = Join-Path $testRoot 'Workbench'
    $publicTool = Join-Path $testRoot 'AgentSessionSync'
    $privateVault = Join-Path $testRoot 'AgentSessionVault'
    New-Item -ItemType Directory -Path $fakeWorkbench, $publicTool, $privateVault -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $publicTool 'Launchers'), (Join-Path $privateVault 'Launchers') -Force | Out-Null
    Write-TestScript (Join-Path $publicTool 'Launchers\Start.ps1') (Join-Path $testRoot 'public.txt')

    $resolved = Resolve-SyncTool -RepoRoot $fakeWorkbench -ToolName AgentSessionSync
    Assert-True ($null -eq $resolved) 'public AgentSessionSync checkout is not auto-selected as a private Vault'

    Write-TestScript (Join-Path $privateVault 'Launchers\Start.ps1') (Join-Path $testRoot 'auto-start.txt')
    Write-TestScript (Join-Path $privateVault 'Launchers\Finish.ps1') (Join-Path $testRoot 'auto-finish.txt')
    $resolved = Resolve-SyncTool -RepoRoot $fakeWorkbench -ToolName AgentSessionSync
    Assert-True ($resolved -and $resolved.ToolRoot -eq [IO.Path]::GetFullPath($privateVault)) 'standard private Vault is auto-discovered'

    $escaped = $false
    try { & (Join-Path $packageRoot 'Start.ps1') -ToolRoot $privateVault -StartScript '..\outside.ps1' } catch { $escaped = $true }
    Assert-True $escaped 'Start launcher rejects a path outside ToolRoot'

    $missing = $false
    try { & (Join-Path $packageRoot 'Finish.ps1') -ToolRoot $privateVault -FinishScript 'Launchers\Missing.ps1' } catch { $missing = $true }
    Assert-True $missing 'registered missing launcher is an error, not a SKIP'

    $startMarker = Join-Path $testRoot 'start-called.txt'
    $finishMarker = Join-Path $testRoot 'finish-called.txt'
    Write-TestScript (Join-Path $privateVault 'Launchers\Start.ps1') $startMarker
    Write-TestScript (Join-Path $privateVault 'Launchers\Finish.ps1') $finishMarker
    & (Join-Path $packageRoot 'Start.ps1') -ToolRoot $privateVault
    Assert-True (Test-Path -LiteralPath $startMarker -PathType Leaf) 'valid Start delegates to the private Vault launcher'
    & (Join-Path $packageRoot 'Finish.ps1') -ToolRoot $privateVault
    Assert-True (Test-Path -LiteralPath $finishMarker -PathType Leaf) 'valid Finish delegates to the private Vault launcher'

    Write-Host "[PASS] AgentSessionSync connector: $passed assertions" -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
