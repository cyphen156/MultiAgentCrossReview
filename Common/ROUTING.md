# Rule Routing - MultiAgentCrossReview

This file is the small always-on routing surface.
It is intentionally shorter than the detailed rule files.

## Always-On Invariants

- Workbench rules and user settings outrank project-specific rules.
- Project rules are plugins. They apply only inside the workbench and user-preference boundaries.
- Always load local user settings from `UserSettings/` private files when present. Do not gate this layer behind tone/style keywords.
- Do not modify a source project repository from this workbench unless the user explicitly asks for that exact operation.
- Keep public review/process artifacts separate from private raw sessions, local credentials, local user settings, and ignored project mirrors.
- When a task depends on rules, inspect the relevant rule file before giving a final answer or drafting an artifact.
- If routing is uncertain, read less but read the right anchor: `Common/SHARED_RULES.md` for workbench behavior, `Projects/<active>/RULES.md` for project behavior, and `UserSettings/` private files for local user settings when present.

## Primary Routing Anchors

Use context anchors before lexical keyword matching.

| Context anchor | Read |
|---|---|
| Task is about MultiAgentCrossReview itself, review process, public/private boundaries, `Reviews/`, `run-review.ps1`, or `sync.ps1` | `Common/SHARED_RULES.md`, then `Reviews/README.md` when record/state flow matters |
| Task mentions or touches a registered project from `Projects/projects.json` | `Projects/<name>/RULES.md` if present |
| Task touches `Projects/<name>/baseline/` or `Projects/<name>/edit/` | `Projects/<name>/RULES.md` and `Common/SHARED_RULES.md` |
| Task asks for commit messages, DevLog, code style, architecture, build/test interpretation, or project-specific conventions | Active project `RULES.md` first, then `Common/SHARED_RULES.md` for generic structure |
| Task is about tone, collaboration style, no-yes-man behavior, private/local preferences, or user-specific workflow | `UserSettings/` private files for details; this layer should already be loaded when present |
| Task is about raw session movement or cross-device continuation | Treat as private transport work; use the relevant AgentSessionSync/vault documents, not public review docs |

## Secondary Keyword Triggers

These keywords help routing, but they are not the first source of truth.
If context already identifies the active project, load that project rule file even when none of these words appear.

- Workbench/process: `MultiAgentCrossReview`, `Reviews`, `REVIEW.md`, `DECISION.md`, `Callback`, `cross-review`, `run-review`, `sync.ps1`, `public`, `private`, `SSOT`.
- Project rules: project name, path under `Projects/<name>/`, `baseline`, `edit/Claud`, `edit/Codex`.
- Commit/DevLog: `commit`, `DevLog`, `커밋`, `데브로그`, `PASS`, `FAIL`, `branch`, `#N_M`.
- Code style/architecture: `Allman`, `lambda`, `Core`, `HAL`, `Platform`, `Renderer`, `Module`, `File`, `Path`, `encoding`, `line ending`.
- User preferences: `tone`, `style`, `존댓말`, `no-yes-man`, `agree`, `disagree`, `검토 태도`.

## Loading Strategy

- Always keep this routing file and the invariants small.
- Do not eagerly load every detailed rule file.
- Always load local user settings when present. They are a base layer, not a keyword-gated layer.
- Load project rules only when the active project or touched paths make them relevant.
- For commit-message or DevLog drafting, the active project rule file is mandatory when a registered project is active. Do not draft from memory when that file is missing; report the missing rule and ask for or create the project rule first.
- Headless review orchestration may inject rules directly in prompts; in that path, the script routing is authoritative.
- Current `Reviews/run-review.ps1` behavior is fail-open for missing project rules: it warns and continues with generic workbench rules only. Interactive commit-message and DevLog drafting remains fail-closed.
