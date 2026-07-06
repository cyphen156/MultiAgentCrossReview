# AgentSessionSync Package Adapter

This package is a local button adapter for the session-sync tool.

AgentSessionSync moves raw Codex/Claude session data. It is intentionally separate from WorkbenchStateSync, which moves review/workbench state such as `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/**`.

This workbench package does not copy session-sync logic; it validates the local `ToolRoot`, delegates to that tool's `Launchers\Start.ps1` / `Launchers\Finish.ps1`, and forwards common root options where they are part of the adapter contract. Point `ToolRoot` at your self-contained AgentSessionVault — the real instance you actually run (tool + real session JSONL). The public AgentSessionSync repository is only the example template.

## Configuration

Copy the example config to the ignored local config path:

```powershell
Copy-Item .\Packages\AgentSessionSync\agentsessionsync.config.example.psd1 .\Packages\AgentSessionSync\agentsessionsync.config.psd1
```

Then set `ToolRoot` to your local AgentSessionVault (the real instance; the public AgentSessionSync is only the example template):

```powershell
@{
    ToolRoot = 'C:\Project\MultiAgent\AgentSessionVault'
    StartScript = ''
    FinishScript = ''
}
```

`AgentSessionSync.local.psd1` at the repository root is also supported and is ignored by git.

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
