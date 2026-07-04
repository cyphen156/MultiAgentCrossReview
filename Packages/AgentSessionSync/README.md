# AgentSessionSync Package Adapter

This package is a local button adapter for the standalone AgentSessionSync tool.

AgentSessionSync moves raw Codex/Claude session data. It is intentionally separate from WorkbenchStateSync, which moves review/workbench state such as `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/**`.

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

Push raw sessions through AgentSessionSync:

```powershell
.\Packages\AgentSessionSync\Finish.ps1
```

The root `Start.ps1` / `Finish.ps1` also run this package when it is configured.
