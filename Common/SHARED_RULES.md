# Shared Rules - Generic Multi-Agent Workbench

This file contains generic MultiAgentCrossReview rules only.
Do not put project-specific code style, architecture, DevLog paths, commit-title conventions, or personal user settings here.

Rule layers:

- Workbench rules: this file, plus `../Reviews/README.md`.
- Project rules: `../Projects/<active>/RULES.md` when an active project exists.
- User settings: private files under `../UserSettings/` when present.
- Agent role notes: `../Claud/ROLE.md` and `../Codex/ROLE.md` add reviewer emphasis only. They do not redefine shared process rules.

Priority:

1. Workbench rules and user settings.
2. Project-specific rules.
3. Prior chat, memory, local habit, or non-SSOT notes.

If these layers conflict, the earlier layer wins. Project rules must run inside the workbench and user-setting boundaries.

Read-before-write gates:

- Before drafting a project commit message, read the active `../Projects/<active>/RULES.md` first, then this file for the generic body structure.
- Before drafting or editing a project DevLog, read the active `../Projects/<active>/RULES.md` first.
- If the active project rule file is missing, do not draft project commit or DevLog text from memory. Report the missing rule file first.

## 1. Core Workbench Invariants

- Claude and Codex are reviewers by default. Code application, final source edits, commits, and pushes are user-controlled unless the user explicitly delegates a specific operation.
- Treat every source repository registered in `../Projects/projects.json` as protected and read-only by default. Resolve write targets before acting; do not create, modify, delete, build in, commit, or push a protected source unless the user's current request explicitly authorizes that exact operation and target repository.
- Authorization for this workbench, its baseline, an `edit/<agent>` copy, review state, sync tooling, or agent memory never implies authorization for the protected source repository.
- Use the live source repository for current branch, HEAD, working-tree state, and document freshness. Verify drift-prone claims from live Git and inspect a cited document's last change before presenting it as current.
- `Projects/<name>/baseline/` is an immutable snapshot for a formal review. Freeze and record its commit when the review starts; do not silently substitute it for live state or refresh it during that review.
- Project rule files contain stable instructions, boundaries, and pointers. Do not copy volatile state into them, including current commit hashes, test totals, measurements, latest log names, or remaining-work lists.
- Preserve measurement scope, unit, configuration, and aggregation labels when citing results. If a copied value has lost its label, return to the cited project evidence instead of guessing.
- Treat agent memory and prior chat as potentially machine-local and stale unless an explicit transport contract says otherwise. They are retrieval aids, not authority for rules, design decisions, or current project state.
- `Projects/<name>/edit/Claud/` and `Projects/<name>/edit/Codex/` are the canonical local agent edit slots. Session-, milestone-, or version-named full-tree candidates are temporary recovery material, never an SSOT or accepted design.
- Before resetting an edit slot or deleting a legacy candidate, inspect its unique diff. Preserve accepted work as a focused patch or formal review artifact; discard rejected or superseded work instead of promoting another full-tree candidate.
- The public workbench keeps only review framework files under `Reviews/`: `README.md`, `_TEMPLATE/`, and review tooling.
- Actual review instances (`Reviews/<review-id>/`) are user-managed workbench state. Keep them in the configured state repository/worktree, not in the public workbench history.
- Raw conversation/session transport belongs outside this public workbench.
- Inside a formal `Reviews/<review-id>/` CrossReview only, initial agent judgments must be independent: do not read the other agent's initial answer before writing your own initial answer.
- After both formal-review initial answers exist, cross-review the other answer and preserve disagreements as useful signal. Do not impose this staged sequence on ordinary conversations, maintenance audits, or user-directed cross-checks.
- User callbacks are review inputs. Treat them as constraints or evidence to evaluate, not as automatic truth.
- Agreement is not the goal. The goal is to expose design flaws, uncertainty, missing evidence, and boundary violations.

## 2. Commit Message Body - Generic Structure

Use this body structure for code commits unless the user requests a narrower output.
Project-specific title format, category names, and indentation rules belong in `../Projects/<active>/RULES.md`.

Required body sections:

```text
변경 요약
	Describe the problem solved by this commit and the direction of the change in 2-4 sentences.
	Do not describe large future work as completed.

상세 변경 내용
	1. First change group
		Describe concrete responsibility, boundary, file-group, or behavior changes.

	2. Second change group
		Focus on verifiable code changes.
```

Optional body sections are an open extension area, not a closed two-item list.
Projects or explicit user instructions may remove, add, or rename optional sections as needed.
The following are common optional sections:

```text
검증
	Write only build/test/run results that were actually performed.
	Preserve original PASS/FAIL counts and failure points.

다음 작업
	Write only work that remains unfinished after this commit.
	Do not leave already implemented items as future work.
```

- Required commit components are: title, `변경 요약`, and `상세 변경 내용`.
- Optional sections are not mandatory commit components. Add, remove, or extend them only when the commit actually needs that information or the user explicitly requests it.
- `검증` and `다음 작업` are common optional sections. Add them only when there are real verification results or remaining work to record.
- Use one blank line between sections. Git may collapse consecutive blank lines.
- Do not put guesses or unverified claims in `검증`.

## 3. DevLog - Generic Principles

Concrete DevLog path, encoding, template, and spacing are project-specific and belong in `../Projects/<active>/RULES.md`.

- DevLog range selection is project-specific and belongs in `../Projects/<active>/RULES.md`.
- DevLogs should summarize the project-specific commit range selected by that rule, not merely the file writing time.

## 4. Review Exchange

Detailed review record rules live in `../Reviews/README.md`.

- `Reviews/<review-id>/README.md` defines the topic, baseline, scope, status, and callbacks inside the user-managed state workspace.
- Each agent writes only its own `REVIEW.md`; the other agent's folder is read-only.
- Current truth is the user-managed state working tree file. History belongs in the configured state repository. Update `REVIEW.md` or `DECISION.md` instead of stacking numbered replacement files.
- Code changes proposed during review happen in local `Projects/<name>/edit/<agent>/` copies.
- Accepted candidate patches or evidence artifacts may be kept under `Reviews/<review-id>/<agent>/artifacts/` only in the user-managed state workspace unless explicitly sanitized for public release.
- Final source application is controlled by the user and should follow `DECISION.md`.
- Topics before 2026-06-28 may use the legacy numbered-file layout. Preserve them as legacy; do not migrate unless explicitly asked.
