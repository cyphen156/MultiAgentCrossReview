# CLAUDE.md - MultiAgentCrossReview

Entry point for Claude Code. Keep this file small. It imports only the routing surface; detailed rules are loaded by route.

@Common/ROUTING.md

Session start gate:

- If `UserSettings/preferences.md` exists in this workspace, read it in full before responding or taking task action. If it does not exist, continue normally.
- This file is scoped to the workspace root, not to an entry in `Projects/projects.json`. Another workspace's preferences never apply here.

Non-negotiable source guard:

- Source repositories registered by `Projects/projects.json` are protected and read-only by default.
- Before any write-capable command or file edit, resolve the target and compare it with every registered `sourceRepoRoot`.
- Do not create, modify, delete, build in, commit, or push a protected source repository unless the user's current request explicitly authorizes that exact operation and target repository.
- Permission to modify this workbench, its baseline, an `edit/<agent>` copy, review state, sync tooling, or agent memory does not transfer to the protected source repository.

- General routing and trigger table: `Common/ROUTING.md`
- Workbench process rules: `Common/SHARED_RULES.md`
- Review state and record format: `Reviews/README.md`
- Active project rules: `Projects/<active>/RULES.md` if present; template: `Common/PROJECT_RULES.template.md`
- Local user settings: always load `UserSettings/` private files first if present; guide: `UserSettings/README.md`
- Claude role notes: `Claud/ROLE.md`
- Codex role reference: `Codex/ROLE.md`
- Project overview: `README.md`

Read-before-write gates:

- Before drafting a project commit message, read the active `Projects/<active>/RULES.md` first, then `Common/SHARED_RULES.md`.
- Before drafting or editing a project DevLog, read the active `Projects/<active>/RULES.md` first.
- If the active project rule file is missing, do not draft the commit message or DevLog from memory. Report the missing rule file first.
