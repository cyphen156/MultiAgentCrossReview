#requires -Version 5.1
# Shared helper: resolve which private Vault (ToolRoot) a sync package should call,
# and read/write the local registry. Dot-sourced by Packages/<Tool>/*.ps1.
#
# Resolution order for a tool (first hit wins):
#   1) UserSettings/sync-tools.json      local, gitignored registry (absolute or relative toolRoot)
#   2) legacy Packages/<Tool>/<tool>.config.psd1   backward-compatible fallback (ToolRoot)
#   3) auto-discovery of standard sibling folders  (private Vault preferred over public Sync)
#
# Auto-discovery only resolves a ToolRoot in memory for the current call; it does NOT
# write sync-tools.json. Persisting a registration is always an explicit action via
# Register.ps1 / Startup.ps1.
#
# Relative toolRoot values are resolved against the MultiAgentCrossReview repo root.
# This layer only points at the tool. The tool's own working-directory config
# (e.g. Vault\AgentSessionSync.config.psd1 with ProjectRoot/ClaudeHome/CodexHome) is
# read by the Vault's own Launchers and is never touched here.

function Get-SyncRegistryPath {
    param([Parameter(Mandatory)][string] $RepoRoot)
    Join-Path $RepoRoot 'UserSettings\sync-tools.json'
}

function Read-SyncRegistry {
    param([Parameter(Mandatory)][string] $RepoRoot)
    $path = Get-SyncRegistryPath $RepoRoot
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { Write-Warning "sync-tools.json parse failed: $($_.Exception.Message)"; return $null }
}

function Resolve-ToolRootPath {
    param([Parameter(Mandatory)][string] $RepoRoot, [Parameter(Mandatory)][string] $ToolRoot)
    if ([IO.Path]::IsPathRooted($ToolRoot)) { return [IO.Path]::GetFullPath($ToolRoot) }
    return [IO.Path]::GetFullPath((Join-Path $RepoRoot $ToolRoot))
}

# Per-tool default launcher names + auto-discovery candidates (relative to RepoRoot; Vault first).
$script:SyncToolDefaults = @{
    'AgentSessionSync' = @{
        StartScript   = 'Launchers\Start.ps1'
        FinishScript  = 'Launchers\Finish.ps1'
        StartupScript = 'Launchers\Initialize-AgentSessionSync.ps1'
        Candidates    = @('..\AgentSessionVault', '..\AgentSessionSync')
    }
    'WorkbenchStateSync' = @{
        StartScript   = 'Launchers\Start.ps1'
        FinishScript  = 'Launchers\Finish.ps1'
        StartupScript = 'Launchers\Initialize-NewMachine.ps1'
        Candidates    = @('..\MultiAgentWorkbenchStateVault', '..\MultiAgentWorkbenchStateSync')
    }
}

function Get-SyncToolDefaults {
    param([Parameter(Mandatory)][string] $ToolName)
    if ($script:SyncToolDefaults.ContainsKey($ToolName)) { return $script:SyncToolDefaults[$ToolName] }
    return @{ StartScript = 'Launchers\Start.ps1'; FinishScript = 'Launchers\Finish.ps1'; StartupScript = ''; Candidates = @() }
}

function Resolve-SyncTool {
    # Returns @{ ToolName; ToolRoot(abs); StartScript; FinishScript; StartupScript; Enabled; Source }
    # or $null when the tool is disabled / not resolvable. Source: registry | legacy-psd1 | auto-discovery
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [Parameter(Mandatory)][string] $ToolName,
        [string] $LegacyConfigPath = ''
    )
    $defaults = Get-SyncToolDefaults $ToolName

    # 1) registry
    $reg = Read-SyncRegistry $RepoRoot
    if ($reg -and $reg.tools -and ($reg.tools.PSObject.Properties.Name -contains $ToolName)) {
        $t = $reg.tools.$ToolName
        $enabled = $true
        if ($t.PSObject.Properties.Name -contains 'enabled') { $enabled = [bool]$t.enabled }
        if (-not $enabled) { return $null }
        if ($t.toolRoot) {
            $start  = if ($t.startScript)   { [string]$t.startScript }   else { $defaults.StartScript }
            $finish = if ($t.finishScript)  { [string]$t.finishScript }  else { $defaults.FinishScript }
            $stup   = if ($t.startupScript) { [string]$t.startupScript } else { $defaults.StartupScript }
            return @{ ToolName = $ToolName; ToolRoot = (Resolve-ToolRootPath $RepoRoot ([string]$t.toolRoot)); StartScript = $start; FinishScript = $finish; StartupScript = $stup; Enabled = $true; Source = 'registry' }
        }
    }

    # 2) legacy psd1 fallback
    if ($LegacyConfigPath -and (Test-Path -LiteralPath $LegacyConfigPath)) {
        try {
            $cfg = Import-PowerShellDataFile -LiteralPath $LegacyConfigPath
            if ($cfg.ContainsKey('ToolRoot') -and $cfg.ToolRoot) {
                $start  = if ($cfg.ContainsKey('StartScript')  -and $cfg.StartScript)  { [string]$cfg.StartScript }  else { $defaults.StartScript }
                $finish = if ($cfg.ContainsKey('FinishScript') -and $cfg.FinishScript) { [string]$cfg.FinishScript } else { $defaults.FinishScript }
                return @{ ToolName = $ToolName; ToolRoot = (Resolve-ToolRootPath $RepoRoot ([string]$cfg.ToolRoot)); StartScript = $start; FinishScript = $finish; StartupScript = $defaults.StartupScript; Enabled = $true; Source = 'legacy-psd1' }
            }
        } catch { Write-Warning "legacy config parse failed ($LegacyConfigPath): $($_.Exception.Message)" }
    }

    # 3) auto-discovery (private Vault preferred)
    foreach ($cand in $defaults.Candidates) {
        $abs = Resolve-ToolRootPath $RepoRoot $cand
        if (Test-Path -LiteralPath (Join-Path $abs $defaults.StartScript)) {
            return @{ ToolName = $ToolName; ToolRoot = $abs; StartScript = $defaults.StartScript; FinishScript = $defaults.FinishScript; StartupScript = $defaults.StartupScript; Enabled = $true; Source = 'auto-discovery' }
        }
    }

    return $null
}

function Write-SyncToolRegistration {
    # Create/update UserSettings/sync-tools.json. Stores $ToolRoot verbatim (relative stays relative).
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [Parameter(Mandatory)][string] $ToolName,
        [Parameter(Mandatory)][string] $ToolRoot,
        [string] $StartScript = '',
        [string] $FinishScript = '',
        [string] $StartupScript = '',
        [bool] $Enabled = $true
    )
    $defaults = Get-SyncToolDefaults $ToolName
    if (-not $StartScript)   { $StartScript   = $defaults.StartScript }
    if (-not $FinishScript)  { $FinishScript  = $defaults.FinishScript }
    if (-not $StartupScript) { $StartupScript = $defaults.StartupScript }

    $path = Get-SyncRegistryPath $RepoRoot
    $obj = $null
    if (Test-Path -LiteralPath $path) { try { $obj = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = $null } }
    if (-not $obj) { $obj = [pscustomobject]@{ version = 1; tools = [pscustomobject]@{} } }
    if (-not ($obj.PSObject.Properties.Name -contains 'tools') -or -not $obj.tools) {
        $obj | Add-Member -NotePropertyName tools -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $entry = [pscustomobject]@{
        enabled       = $Enabled
        toolRoot      = $ToolRoot
        startScript   = $StartScript
        finishScript  = $FinishScript
        startupScript = $StartupScript
    }
    if ($obj.tools.PSObject.Properties.Name -contains $ToolName) { $obj.tools.$ToolName = $entry }
    else { $obj.tools | Add-Member -NotePropertyName $ToolName -NotePropertyValue $entry -Force }

    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    ($obj | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}
