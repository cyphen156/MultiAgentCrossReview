# AGENTS.md - MultiAgentCrossReview

Entry point for Codex. Keep this file small. It is a routing surface, not the full rulebook.

Session start gate:

- Before responding or taking task action in this workbench, read `Common/ROUTING.md` and `Common/SHARED_RULES.md` in full. These are mandatory workbench layers, not keyword-gated references.
- If `UserSettings/preferences.md` exists in this workspace, read it in full before responding or taking task action. If it does not exist, continue normally.
- This file is scoped to the workspace root, not to an entry in `Projects/projects.json`. Another workspace's preferences never apply here.

Always apply these invariants:

- Public workbench rules and private user settings outrank project-specific rules.
- Source repositories registered by `Projects/projects.json` are protected and read-only by default.
- Before any write-capable command or file edit, resolve the target and compare it with every registered `sourceRepoRoot`.
- Do not create, modify, delete, build in, commit, or push a protected source repository unless the user's current request explicitly authorizes that exact operation and target repository.
- Permission to modify this workbench, its baseline, an `edit/<agent>` copy, review state, sync tooling, or agent memory does not transfer to the protected source repository.
- Current state comes from live Git and current project documents — never from a rule file, a mirror, or memory. Check a document's last change before quoting it as current.
- Agent memory and prior chat are machine-local retrieval aids. They are not authority for rules, decisions, or current project state.
- Keep public review/process artifacts separate from private raw session data and local user settings.
- For tasks that depend on repository rules, inspect the relevant rule file before drafting conclusions.

Routing:

- General routing and trigger table: `Common/ROUTING.md`
- Workbench process rules: `Common/SHARED_RULES.md`
- What a baseline contains (mirror spec format): `Common/MIRROR_SPEC.md`
- Review state and record format: `Reviews/README.md`
- Active project rules: `Projects/<active>/RULES.md` if present; template: `Common/PROJECT_RULES.template.md`
- Local preferences: always load `UserSettings/preferences.md` if present; load other `UserSettings/` files only when the current task routes to them; guide: `UserSettings/README.md`
- Codex role notes: `Codex/ROLE.md`
- Claude role reference: `Claud/ROLE.md`
- Project overview: `README.md`

Read-before-write gates:

- If the active project's `Projects/<active>/RULES.md` exists, read it before drafting a project commit message or DevLog and apply it only to that project.
- If no project rule file exists, continue with `Common/SHARED_RULES.md`; do not invent project-specific title formats, paths, encodings, templates, or conventions.
- A generic commit-message draft may use the shared body structure. A DevLog file edit still requires an explicit or discoverable target path and format.
