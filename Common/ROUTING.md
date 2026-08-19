# Rule Routing - MultiAgentCrossReview

This file is the small always-on routing surface.
It is intentionally shorter than the detailed rule files.

Every agent operating inside this workbench must load this file and `Common/SHARED_RULES.md` before responding or taking task action. Routing decides which additional conditional layers apply; it does not make the shared rules optional.

## Always-On Invariants

- Source protection, permission boundaries, and other non-negotiable workbench invariants outrank user preferences and project-specific rules.
- Project rules are optional plugins. When present, they are mandatory for their active project and apply only inside the workbench and user-preference boundaries.
- Always load `UserSettings/preferences.md` when it is present. Its existence is optional, but its application is mandatory. Load other private `UserSettings/` files only when the current task routes to their purpose; do not treat handoff notes, machine notes, or patch records as always-on preferences.
- Registered source repositories (`Projects/projects.json` → `sourceRepoRoot`) are read-only by default. Resolve the write target before acting. Permission for this workbench, a baseline, an `edit/<agent>` copy, review state, sync tooling, or agent memory never transfers to them.
- Use `Projects/<name>/baseline/` as the default read-only code and document reference surface when it is available. It is copied from the source repository's local files at sync time, within the scope declared by `Projects/<name>/mirror.json`, and may therefore include uncommitted local content while omitting paths the spec does not declare. Use live Git for current HEAD, status, and freshness checks; treat a recorded commit as source metadata, not as the definition of the baseline contents. Inspect the protected source tree directly only when the baseline cannot answer the question, a path falls outside the spec scope, or a live difference must be verified.
- Current state comes from live Git and current project documents — never from a rule file, a mirror, or memory. Check a document's last change before quoting it as current.
- Agent memory and prior chat are machine-local retrieval aids. They are not authority for rules, decisions, or current project state.
- Keep public review/process artifacts separate from private raw sessions, local credentials, local user settings, and ignored project mirrors.
- Always apply `Common/SHARED_RULES.md`. When a task has an active project, also load that project's `Projects/<name>/RULES.md` if it exists.
- If project routing is uncertain, do not select the first registered project by habit. Resolve the project from the user's request and touched paths; if none is active, use shared rules only.

## Primary Routing Anchors

Use context anchors before lexical keyword matching.

| Context anchor | Read |
|---|---|
| Task is about MultiAgentCrossReview itself, review process, public/private boundaries, `Reviews/`, `run-review.ps1`, or `sync.ps1` | `Common/SHARED_RULES.md`, then `Reviews/README.md` when record/state flow matters |
| Task mentions or touches a registered project from `Projects/projects.json` | `Projects/<name>/RULES.md` if present; otherwise keep using shared rules only |
| Task touches `Projects/<name>/baseline/` or `Projects/<name>/edit/` | Always `Common/SHARED_RULES.md`, plus `Projects/<name>/RULES.md` if present |
| Task asks what a baseline contains or omits, changes what gets mirrored, adds a project to the mirror, or touches `sync.ps1` / `Packages/ProjectSync/` | `Common/MIRROR_SPEC.md`, then that project's `Projects/<name>/mirror.json` |
| Task sets up a new workbench or machine, or changes shared tooling that other workbenches also use (`Packages/**`, root `sync.ps1`) | `Common/PACKAGE_PROPAGATION.md` |
| Task asks for commit messages, DevLog, code style, architecture, build/test interpretation, or project-specific conventions | Shared rules always; active project `RULES.md` additionally when present |
| Task is about tone, collaboration style, no-yes-man behavior, or stable local preferences | `UserSettings/preferences.md`; this file should already be loaded when present |
| Task is about handoff state, machine notes, local registries, or pending patches | The matching `UserSettings/` file only; these files are task-routed, not always-on |
| Task is about raw session movement or cross-device continuation | Treat as private transport work; use the relevant AgentSessionSync/vault documents, not public review docs |

## Secondary Keyword Triggers

These keywords help routing, but they are not the first source of truth.
If context already identifies the active project, load that project rule file even when none of these words appear.

- Workbench/process: `MultiAgentCrossReview`, `Reviews`, `REVIEW.md`, `DECISION.md`, `Callback`, `cross-review`, `run-review`, `sync.ps1`, `public`, `private`, `SSOT`.
- Mirror spec: `mirror.json`, `mirror spec`, `미러 스펙`, `ProjectSync`, `baseline 범위`, `무엇을 미러`.
- Project rules: project name, path under `Projects/<name>/`, `baseline`, `edit/Claud`, `edit/Codex`.
- Commit/DevLog: `commit`, `DevLog`, `커밋`, `데브로그`, `PASS`, `FAIL`, `branch`, `#N_M`.
- Code style/architecture: `Allman`, `lambda`, `Core`, `HAL`, `Platform`, `Renderer`, `Module`, `File`, `Path`, `encoding`, `line ending`.
- User preferences: `tone`, `style`, `존댓말`, `no-yes-man`, `agree`, `disagree`, `검토 태도`.

## Loading Strategy

- Always keep this routing file and the invariants small.
- Always load `Common/SHARED_RULES.md`; do not eagerly load unrelated project or formal-review files.
- Always load `UserSettings/preferences.md` when present. It is a base layer, not a keyword-gated layer; other `UserSettings/` files remain task-routed.
- Load a project rule file only when the active project or touched paths make it relevant. Its existence is optional, but application is mandatory when it exists.
- Without a project rule file, generic commit-message drafting may use the shared body structure. Do not invent project-specific title formats, DevLog paths, encodings, templates, or conventions.
- Headless review orchestration may inject rules directly in prompts; in that path, the script routing is authoritative.
- Formal registered-project reviews require a verified baseline, but they do not require a project rule file. Missing optional project rules are recorded and the review continues with shared rules.
