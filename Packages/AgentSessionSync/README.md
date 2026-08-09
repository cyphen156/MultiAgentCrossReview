# AgentSessionSync Package Adapter

This package is a local button adapter for the session-sync tool.

AgentSessionSync moves raw Codex/Claude session data. It is intentionally separate from WorkbenchStateSync, which moves review/workbench state such as `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/**`.

Its transport unit is the **agent app index, not a project**, so this adapter's scope is not the workbench: a single registered `ToolRoot` carries every conversation on the machine regardless of which project it belongs to. Session retention (the archive tier, tombstones, `ActiveWindowDays`) is the tool's own contract — see the vault's `README.md` — and is not configured from here.

This workbench package does not copy session-sync logic; it validates the local `ToolRoot`, delegates to that tool's `Launchers\Start.ps1` / `Launchers\Finish.ps1`, and forwards common root options where they are part of the adapter contract. Point `ToolRoot` at your self-contained AgentSessionVault — the real instance you actually run (tool + real session JSONL). The public AgentSessionSync repository is only the example template.

## Configuration

Copy the example config to the ignored local config path:

```powershell
.\Packages\AgentSessionSync\Register.ps1 -ToolRoot C:\Path\To\AgentSessionVault
```

This registers your AgentSessionVault (the real instance; the public AgentSessionSync is only the example template) into the ignored local registry `UserSettings/sync-tools.json`. `toolRoot` may be absolute or relative (relative is resolved from the workbench root). The legacy `Packages/AgentSessionSync/agentsessionsync.config.psd1` (and root `AgentSessionSync.local.psd1`) still work as a backward-compatible fallback.

## Usage

Pull raw sessions through AgentSessionSync:

```powershell
.\Packages\AgentSessionSync\Start.ps1
```

Taskbar shortcuts are generated centrally from the workbench root:

```powershell
.\Launchers\Create-Shortcuts.ps1
```

Push raw sessions through AgentSessionSync:

```powershell
.\Packages\AgentSessionSync\Finish.ps1
```

The root `Start.ps1` / `Finish.ps1` also run this package when it is configured.

If no local config exists, or if the configured external scripts are missing, the adapter skips with a message instead of failing the entire root Start/Finish run.
