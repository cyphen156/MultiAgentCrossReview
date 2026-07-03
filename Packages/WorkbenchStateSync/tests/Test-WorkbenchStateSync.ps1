#requires -Version 5.1
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'

$script = Resolve-Path (Join-Path $PSScriptRoot '..\workbenchstatesync.ps1')
$root = Join-Path ([IO.Path]::GetTempPath()) ("WorkbenchStateSync-Test-" + [guid]::NewGuid().ToString('N'))
$worktree = Join-Path $root 'worktree'
$vault = Join-Path $root 'vault'

try {
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $worktree 'UserSettings'), `
        (Join-Path $worktree 'Projects\Demo'), `
        (Join-Path $worktree 'Projects\Demo\baseline'), `
        (Join-Path $worktree 'Projects\Demo\edit\Codex'), `
        (Join-Path $worktree 'Reviews\2026-07-04_Demo\Codex\artifacts'), `
        (Join-Path $worktree 'Reviews\_TEMPLATE') | Out-Null

    'tone prefs' | Set-Content -LiteralPath (Join-Path $worktree 'UserSettings\preferences.md') -Encoding UTF8
    'public guide' | Set-Content -LiteralPath (Join-Path $worktree 'UserSettings\README.md') -Encoding UTF8
    'project rules' | Set-Content -LiteralPath (Join-Path $worktree 'Projects\Demo\RULES.md') -Encoding UTF8
    'baseline data' | Set-Content -LiteralPath (Join-Path $worktree 'Projects\Demo\baseline\ignored.md') -Encoding UTF8
    'edit data' | Set-Content -LiteralPath (Join-Path $worktree 'Projects\Demo\edit\Codex\ignored.md') -Encoding UTF8
    'review topic' | Set-Content -LiteralPath (Join-Path $worktree 'Reviews\2026-07-04_Demo\README.md') -Encoding UTF8
    'review body' | Set-Content -LiteralPath (Join-Path $worktree 'Reviews\2026-07-04_Demo\Codex\REVIEW.md') -Encoding UTF8
    'candidate patch' | Set-Content -LiteralPath (Join-Path $worktree 'Reviews\2026-07-04_Demo\Codex\artifacts\candidate.patch') -Encoding UTF8
    'public review docs' | Set-Content -LiteralPath (Join-Path $worktree 'Reviews\README.md') -Encoding UTF8
    'template' | Set-Content -LiteralPath (Join-Path $worktree 'Reviews\_TEMPLATE\README.md') -Encoding UTF8
    'tool' | Set-Content -LiteralPath (Join-Path $worktree 'Reviews\run-review.ps1') -Encoding UTF8

    & $script -Direction Push -WorktreeRoot $worktree -VaultRoot $vault
    if ($LASTEXITCODE -ne 0) { throw 'Push failed.' }

    if (-not (Test-Path (Join-Path $vault 'UserSettings\preferences.md'))) { throw 'UserSettings file was not pushed.' }
    if (Test-Path (Join-Path $vault 'UserSettings\README.md')) { throw 'UserSettings README.md was pushed.' }
    if (-not (Test-Path (Join-Path $vault 'Projects\Demo\RULES.md'))) { throw 'Project RULES.md was not pushed.' }
    if (Test-Path (Join-Path $vault 'Projects\Demo\baseline\ignored.md')) { throw 'baseline file was pushed.' }
    if (Test-Path (Join-Path $vault 'Projects\Demo\edit\Codex\ignored.md')) { throw 'edit file was pushed.' }
    if (-not (Test-Path (Join-Path $vault 'Reviews\2026-07-04_Demo\README.md'))) { throw 'Review README was not pushed.' }
    if (-not (Test-Path (Join-Path $vault 'Reviews\2026-07-04_Demo\Codex\REVIEW.md'))) { throw 'Review file was not pushed.' }
    if (-not (Test-Path (Join-Path $vault 'Reviews\2026-07-04_Demo\Codex\artifacts\candidate.patch'))) { throw 'Review artifact was not pushed.' }
    if (Test-Path (Join-Path $vault 'Reviews\README.md')) { throw 'Public Reviews README was pushed.' }
    if (Test-Path (Join-Path $vault 'Reviews\_TEMPLATE\README.md')) { throw 'Review template was pushed.' }
    if (Test-Path (Join-Path $vault 'Reviews\run-review.ps1')) { throw 'Review tool was pushed.' }

    'local changed' | Set-Content -LiteralPath (Join-Path $worktree 'UserSettings\preferences.md') -Encoding UTF8
    'vault changed' | Set-Content -LiteralPath (Join-Path $vault 'UserSettings\preferences.md') -Encoding UTF8

    & $script -Direction Pull -WorktreeRoot $worktree -VaultRoot $vault
    if ($LASTEXITCODE -ne 0) { throw 'Pull failed.' }
    $local = Get-Content -Raw -LiteralPath (Join-Path $worktree 'UserSettings\preferences.md')
    if ($local -notmatch 'local changed') { throw 'Divergent local file was overwritten without -Force.' }
    $backup = Get-ChildItem -LiteralPath (Join-Path $worktree 'UserSettings') -Filter 'preferences.md.bak-*' -File
    if (-not $backup) { throw 'Backup was not created for divergent local file.' }

    & $script -Direction Pull -WorktreeRoot $worktree -VaultRoot $vault -Force
    if ($LASTEXITCODE -ne 0) { throw 'Force pull failed.' }
    $forced = Get-Content -Raw -LiteralPath (Join-Path $worktree 'UserSettings\preferences.md')
    if ($forced -notmatch 'vault changed') { throw 'Force pull did not overwrite destination.' }

    $configWorktree = Join-Path $root 'config-worktree'
    $configVault = Join-Path $root 'config-vault'
    New-Item -ItemType Directory -Force -Path (Join-Path $configWorktree 'UserSettings') | Out-Null
    'config prefs' | Set-Content -LiteralPath (Join-Path $configWorktree 'UserSettings\preferences.md') -Encoding UTF8
    $packageRoot = Split-Path -Parent $script
    $configPath = Join-Path $packageRoot 'workbenchstatesync.config.psd1'
    $oldConfig = if (Test-Path -LiteralPath $configPath) { Get-Content -Raw -LiteralPath $configPath -Encoding UTF8 } else { $null }
    "@{`n    VaultRoot = '$($configVault.Replace("'", "''"))'`n    WorktreeRoot = '$($configWorktree.Replace("'", "''"))'`n}`n" |
        Set-Content -LiteralPath $configPath -Encoding UTF8
    try {
        & $script -Direction Push
        if ($LASTEXITCODE -ne 0) { throw 'Config-based push failed.' }
        if (-not (Test-Path (Join-Path $configVault 'UserSettings\preferences.md'))) { throw 'Config-based push did not use local config.' }
    }
    finally {
        if ($null -ne $oldConfig) { Set-Content -LiteralPath $configPath -Value $oldConfig -Encoding UTF8 -NoNewline }
        elseif (Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath -Force }
    }

    $secretWorktree = Join-Path $root 'secret-worktree'
    $secretVault = Join-Path $root 'secret-vault'
    New-Item -ItemType Directory -Force -Path (Join-Path $secretWorktree 'UserSettings') | Out-Null
    (('sk-ant-' + 'api03-') + ('a' * 64)) | Set-Content -LiteralPath (Join-Path $secretWorktree 'UserSettings\preferences.md') -Encoding UTF8
    $secretBlocked = $false
    try {
        & $script -Direction Push -WorktreeRoot $secretWorktree -VaultRoot $secretVault
    }
    catch {
        $secretBlocked = $true
    }
    if (-not $secretBlocked) { throw 'Secret-like content was not blocked.' }

    $wrapperRemote = Join-Path $root 'wrapper-remote.git'
    $wrapperVault = Join-Path $root 'wrapper-vault'
    $wrapperWorktree = Join-Path $root 'wrapper-worktree'
    $wrapperReceiver = Join-Path $root 'wrapper-receiver'
    $startScript = Resolve-Path (Join-Path $PSScriptRoot '..\Start.ps1')
    $finishScript = Resolve-Path (Join-Path $PSScriptRoot '..\Finish.ps1')

    & git init --bare $wrapperRemote | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Wrapper test remote init failed.' }
    & git clone $wrapperRemote $wrapperVault | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Wrapper test state repo clone failed.' }
    & git -C $wrapperVault config user.email 'workbench-state-sync-test@example.invalid'
    & git -C $wrapperVault config user.name 'WorkbenchStateSync Test'
    New-Item -ItemType Directory -Force -Path (Join-Path $wrapperVault 'UserSettings') | Out-Null
    'initial prefs' | Set-Content -LiteralPath (Join-Path $wrapperVault 'UserSettings\preferences.md') -Encoding UTF8
    & git -C $wrapperVault add UserSettings
    & git -C $wrapperVault commit -m 'seed state' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Wrapper test seed commit failed.' }
    & git -C $wrapperVault push origin master | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Wrapper test seed push failed.' }

    New-Item -ItemType Directory -Force -Path (Join-Path $wrapperWorktree 'UserSettings') | Out-Null
    'updated prefs from worktree' | Set-Content -LiteralPath (Join-Path $wrapperWorktree 'UserSettings\preferences.md') -Encoding UTF8
    & $finishScript -VaultRoot $wrapperVault -WorktreeRoot $wrapperWorktree -CommitMessage 'workbench state test update'
    if ($LASTEXITCODE -ne 0) { throw 'Finish wrapper failed.' }

    $wrapperLog = & git -C $wrapperVault log -1 --pretty=%s
    if ($wrapperLog -ne 'workbench state test update') { throw 'Finish wrapper did not commit state update.' }

    New-Item -ItemType Directory -Force -Path $wrapperReceiver | Out-Null
    & $startScript -VaultRoot $wrapperVault -WorktreeRoot $wrapperReceiver
    if ($LASTEXITCODE -ne 0) { throw 'Start wrapper failed.' }
    $received = Get-Content -Raw -LiteralPath (Join-Path $wrapperReceiver 'UserSettings\preferences.md')
    if ($received -notmatch 'updated prefs from worktree') { throw 'Start wrapper did not materialize pushed state.' }

    Write-Host '[PASS] WorkbenchStateSync round trip and conflict guard succeeded.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
