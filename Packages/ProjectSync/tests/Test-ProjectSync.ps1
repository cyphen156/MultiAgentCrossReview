#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptUnderTest = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'Sync.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ProjectSyncTests-' + [guid]::NewGuid().ToString('N'))
$workbench = Join-Path $testRoot 'Workbench'
$syncPath = Join-Path $workbench 'Packages\ProjectSync\Sync.ps1'
$projects = Join-Path $workbench 'Projects'
$sourceA = Join-Path $testRoot 'SourceA'
$sourceB = Join-Path $testRoot 'SourceB'
$passed = 0

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) { throw "ASSERT FAILED: $message" }
    $script:passed++
}
function Write-Json([string] $path, $value) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding UTF8
}
function Write-Manifest($entries) {
    Write-Json (Join-Path $projects 'projects.json') ([ordered]@{ projects = @($entries) })
}
function Write-Spec([string] $name, $items, [string] $sourceCountPath = '') {
    $spec = [ordered]@{ version = 1; items = @($items) }
    if ($sourceCountPath) { $spec.sourceCountPath = $sourceCountPath }
    Write-Json (Join-Path $projects "$name\MirrorTargets.json") $spec
}
function Invoke-Sync([string[]] $arguments = @()) {
    # PowerShell 5.1 can turn a native child's redirected stderr into a terminating
    # NativeCommandError when the parent uses ErrorActionPreference=Stop. Capture both
    # streams through files so the harness behaves the same under every host.
    $token = [guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path $testRoot "child-$token.stdout.txt"
    $stderrPath = Join-Path $testRoot "child-$token.stderr.txt"
    $nativeArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $syncPath + '"')) + @($arguments)
    try {
        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $nativeArgs -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -Wait -PassThru
        $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue } else { '' }
        $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue } else { '' }
        $output = (@($stdout, $stderr) | Where-Object { $_ }) -join "`n"
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output.TrimEnd() }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $syncPath), (Join-Path $sourceA 'Source'), (Join-Path $sourceB 'Docs') -Force | Out-Null
    Copy-Item -LiteralPath $scriptUnderTest -Destination $syncPath -Force
    'A1' | Set-Content -LiteralPath (Join-Path $sourceA 'Source\a.txt') -Encoding UTF8
    'optional' | Set-Content -LiteralPath (Join-Path $sourceA 'README.md') -Encoding UTF8
    'B1' | Set-Content -LiteralPath (Join-Path $sourceB 'Docs\b.txt') -Encoding UTF8

    $entryA = [ordered]@{ name = 'Alpha'; sourceRepoRoot = $sourceA }
    $entryB = [ordered]@{ name = 'Beta'; sourceRepoRoot = $sourceB }
    Write-Manifest @($entryA, $entryB)
    Write-Spec 'Alpha' @(
        [ordered]@{ kind = 'tree'; from = 'Source'; required = $true },
        [ordered]@{ kind = 'file'; from = 'README.md' }
    ) 'Source'
    Write-Spec 'Beta' @([ordered]@{ kind = 'tree'; from = 'Docs'; required = $true }) 'Docs'

    $result = Invoke-Sync
    Assert-True ($result.ExitCode -eq 0) "multi-project sync failed:`n$($result.Output)"
    Assert-True (Test-Path -LiteralPath (Join-Path $projects 'Alpha\baseline\Source\a.txt')) 'Alpha baseline missing'
    Assert-True (Test-Path -LiteralPath (Join-Path $projects 'Beta\baseline\Docs\b.txt')) 'Beta baseline missing'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $projects 'Alpha') -Directory -Filter '.baseline-*-*').Count -eq 0) 'temporary baseline directory remained'

    $alphaRoot = Join-Path $projects 'Alpha'
    $staleStaging = Join-Path $alphaRoot '.baseline-staging-stale'
    $staleBackup = Join-Path $alphaRoot '.baseline-backup-stale'
    New-Item -ItemType Directory -Path $staleStaging, $staleBackup -Force | Out-Null
    $result = Invoke-Sync @('-Project', 'Alpha')
    Assert-True ($result.ExitCode -eq 0) "stale temporary cleanup failed:`n$($result.Output)"
    Assert-True (-not (Test-Path -LiteralPath $staleStaging)) 'stale staging directory survived'
    Assert-True (-not (Test-Path -LiteralPath $staleBackup)) 'obsolete backup survived while baseline existed'

    $recoverBackup = Join-Path $alphaRoot '.baseline-backup-recover'
    Move-Item -LiteralPath (Join-Path $alphaRoot 'baseline') -Destination $recoverBackup
    $result = Invoke-Sync @('-Project', 'Alpha')
    Assert-True ($result.ExitCode -eq 0) "single backup recovery failed:`n$($result.Output)"
    Assert-True ($result.Output -match 'baseline.*복구') 'single backup recovery was not reported'
    Assert-True (Test-Path -LiteralPath (Join-Path $alphaRoot 'baseline')) 'baseline was not restored from the single backup'

    $ambiguousOne = Join-Path $alphaRoot '.baseline-backup-one'
    $ambiguousTwo = Join-Path $alphaRoot '.baseline-backup-two'
    Move-Item -LiteralPath (Join-Path $alphaRoot 'baseline') -Destination $ambiguousOne
    Copy-Item -LiteralPath $ambiguousOne -Destination $ambiguousTwo -Recurse
    $result = Invoke-Sync @('-Project', 'Alpha')
    Assert-True ($result.ExitCode -ne 0) 'multiple backups without a baseline were guessed automatically'
    Assert-True ((Test-Path -LiteralPath $ambiguousOne) -and (Test-Path -LiteralPath $ambiguousTwo)) 'ambiguous backups were deleted'
    Move-Item -LiteralPath $ambiguousOne -Destination (Join-Path $alphaRoot 'baseline')
    Remove-Item -LiteralPath $ambiguousTwo -Recurse -Force

    $codexEdit = Join-Path $projects 'Alpha\edit\Codex'
    'user edit' | Set-Content -LiteralPath (Join-Path $codexEdit 'user.txt') -Encoding UTF8
    'A2' | Set-Content -LiteralPath (Join-Path $sourceA 'Source\a.txt') -Encoding UTF8
    Remove-Item -LiteralPath (Join-Path $sourceA 'README.md') -Force
    $result = Invoke-Sync @('-Project', 'Alpha')
    Assert-True ($result.ExitCode -eq 0) "single-project resync failed:`n$($result.Output)"
    Assert-True ((Get-Content -LiteralPath (Join-Path $projects 'Alpha\baseline\Source\a.txt') -Raw).Trim() -eq 'A2') 'baseline did not update'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projects 'Alpha\baseline\README.md'))) 'stale optional file survived'
    Assert-True (Test-Path -LiteralPath (Join-Path $codexEdit 'user.txt')) 'edit copy was overwritten without ResetEdit'

    $result = Invoke-Sync @('-Project', 'Alpha', '-ResetEdit', 'Codex')
    Assert-True ($result.ExitCode -eq 0) "ResetEdit failed:`n$($result.Output)"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $codexEdit 'user.txt'))) 'ResetEdit did not replace Codex edit copy'
    Assert-True ((Get-Content -LiteralPath (Join-Path $codexEdit 'Source\a.txt') -Raw).Trim() -eq 'A2') 'ResetEdit did not seed current baseline'

    $sentinel = Join-Path $projects 'Alpha\baseline\sentinel.txt'
    'keep' | Set-Content -LiteralPath $sentinel -Encoding UTF8
    Write-Spec 'Alpha' @([ordered]@{ kind = 'tree'; from = 'Missing'; required = $true })
    $result = Invoke-Sync @('-Project', 'Alpha')
    Assert-True ($result.ExitCode -ne 0) 'missing required source was accepted'
    Assert-True ((Get-Content -LiteralPath $sentinel -Raw).Trim() -eq 'keep') 'failed validation changed the live baseline'

    Write-Spec 'Alpha' @(
        [ordered]@{ kind = 'tree'; from = 'Source'; to = '.'; required = $true },
        [ordered]@{ kind = 'file'; from = 'README.md'; to = 'README.md' }
    )
    $result = Invoke-Sync @('-Project', 'Alpha', '-DryRun')
    Assert-True ($result.ExitCode -ne 0) 'overlapping destinations were accepted by DryRun'
    Assert-True ((Get-Content -LiteralPath $sentinel -Raw).Trim() -eq 'keep') 'DryRun changed the baseline'

    Write-Spec 'Alpha' @([ordered]@{ kind = 'tree'; from = 'Source'; to = '..\escape'; required = $true })
    $result = Invoke-Sync @('-Project', 'Alpha', '-DryRun')
    Assert-True ($result.ExitCode -ne 0) 'destination traversal was accepted'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projects 'escape'))) 'destination traversal created a directory'

    Write-Manifest @([ordered]@{ name = '..\escaped'; sourceRepoRoot = $sourceA })
    $result = Invoke-Sync @('-DryRun')
    Assert-True ($result.ExitCode -ne 0) 'project-name traversal was accepted'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $workbench 'escaped'))) 'project-name traversal escaped Projects'

    Write-Manifest @([ordered]@{ name = 'Relative'; sourceRepoRoot = '.\source' })
    $result = Invoke-Sync @('-DryRun')
    Assert-True ($result.ExitCode -ne 0) 'relative sourceRepoRoot was accepted'
    Write-Host "ProjectSync tests passed: $passed assertions" -ForegroundColor Green
} finally {
    $fullTestRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($fullTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $fullTestRoot).StartsWith('ProjectSyncTests-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $fullTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
