# AGENTS.md - MultiAgentCrossReview

Entry point for Codex. Keep this file small. It is a routing surface, not the full rulebook.

Always apply these invariants:

- Public workbench rules and private user settings outrank project-specific rules.
- Do not modify the source project repository from this workbench unless the user explicitly asks for that exact operation.
- Keep public review/process artifacts separate from private raw session data and local user settings.
- For tasks that depend on repository rules, inspect the relevant rule file before drafting conclusions.

Routing:

- General routing and trigger table: `Common/ROUTING.md`
- Workbench process rules: `Common/SHARED_RULES.md`
- Review state and record format: `Reviews/README.md`
- Active project rules: `Projects/<active>/RULES.md` if present; template: `Common/PROJECT_RULES.template.md`
- Local user settings: always load `UserSettings/` private files first if present; guide: `UserSettings/README.md`
- Codex role notes: `Codex/ROLE.md`
- Claude role reference: `Claud/ROLE.md`
- Project overview: `README.md`

Read-before-write gates:

- Before drafting a project commit message, read the active `Projects/<active>/RULES.md` first, then `Common/SHARED_RULES.md`.
- Before drafting or editing a project DevLog, read the active `Projects/<active>/RULES.md` first.
- If the active project rule file is missing, do not draft the commit message or DevLog from memory. Report the missing rule file first.
