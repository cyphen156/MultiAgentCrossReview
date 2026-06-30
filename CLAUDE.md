# CLAUDE.md - MultiAgentCrossReview

Entry point for Claude Code. Keep this file small. It imports only the routing surface; detailed rules are loaded by route.

@Common/ROUTING.md

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
