# 2026-07-04_WorkbenchStateBoundary

## Topic

Decide where mutable MultiAgentCrossReview state belongs after separating public framework files from real review records.

## Baseline

- Repository: `MultiAgentCrossReview`
- Framework commit: public framework state after removing tracked real review instances
- State sync tool: `WorkbenchStateSync`

## Scope

In scope:

- `UserSettings/**/*.md`
- `Projects/<name>/RULES.md`
- `Reviews/<review-id>/**`
- public examples showing the state shape

Out of scope:

- raw Codex/Claude session JSONL
- project baseline and edit mirrors
- tokens, credentials, machine-local paths, and build logs

## Callback

The public repository still needs one visible, sanitized example so a reader can understand how the state repository is supposed to look.

## Status

Decided.
