# ProjectSync

ProjectSync is the package button for the workbench project mirror sync script.

It wraps the root `sync.ps1`, which refreshes `Projects/<name>/baseline/` and agent edit copies from the configured source project repositories.

ProjectSync lives at the repository root, outside `Packages/`. It is a built-in one-way project mirror refresh and is intentionally not part of root `Start.ps1` / `Finish.ps1`.

## Usage

Refresh all configured projects:

```powershell
.\ProjectSync\Start.ps1
```

The central Windows launcher is:

```text
.\Launchers\ProjectSync.cmd
```

Refresh one project:

```powershell
.\ProjectSync\Start.ps1 -Project CyphenEngine
```

Reset edit mirrors:

```powershell
.\ProjectSync\Start.ps1 -ResetEdit All
```
