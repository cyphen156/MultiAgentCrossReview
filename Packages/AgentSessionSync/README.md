# AgentSessionSync Package Adapter

This package is a local button adapter for the standalone AgentSessionSync tool.

AgentSessionSync moves raw Codex/Claude session data. It is intentionally separate from WorkbenchStateSync, which moves review/workbench state such as `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/**`.

The standalone AgentSessionSync repository is canonical. This workbench package does not copy session-sync logic; it validates the local `ToolRoot`, delegates to that tool's `Start.ps1` / `Finish.ps1`, and forwards common root options where they are part of the adapter contract.

## Configuration

Copy the example config to the ignored local config path:

```powershell
Copy-Item .\Packages\AgentSessionSync\agentsessionsync.config.example.psd1 .\Packages\AgentSessionSync\agentsessionsync.config.psd1
```

Then set `ToolRoot` to the local clone/path of the standalone AgentSessionSync repository:

```powershell
@{
    ToolRoot = 'D:\Tools\AgentSessionSync'
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

Named Windows launcher:

```text
Packages\AgentSessionSync\AgentSessionSync Start.cmd
```

Push raw sessions through AgentSessionSync:

```powershell
.\Packages\AgentSessionSync\Finish.ps1
```

Named Windows launcher:

```text
Packages\AgentSessionSync\AgentSessionSync Finish.cmd
```

The root `Start.ps1` / `Finish.ps1` also run this package when it is configured.

If no local config exists, or if the configured external scripts are missing, the adapter skips with a message instead of failing the entire root Start/Finish run.
