# ProjectSync

ProjectSync is the package button for the workbench project mirror sync script.

It wraps the root `sync.ps1`, which refreshes `Projects/<name>/baseline/` and agent edit copies from the configured source project repositories.

ProjectSync is listed in `Packages/sync-tools.json` with `enabled: false`, so root `Start.ps1` / `Finish.ps1` show it as disabled instead of discovering it by file presence. Project mirror refresh is a work-in-progress operation that is often run manually while reviewing code. It must not be pulled into conversation/session/state sync by accident.

## Usage

Refresh all configured projects:

```powershell
.\Packages\ProjectSync\Start.ps1
```

Named Windows launcher:

```text
Packages\ProjectSync\ProjectSync Start.cmd
```

Refresh one project:

```powershell
.\Packages\ProjectSync\Start.ps1 -Project CyphenEngine
```

Reset edit mirrors:

```powershell
.\Packages\ProjectSync\Start.ps1 -ResetEdit All
```
