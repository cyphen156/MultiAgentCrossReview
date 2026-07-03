Review-ID: 2026-07-04_WorkbenchStateBoundary
Author: User
Baseline: public-framework-boundary
Session-Id:
Status: Decided

# Decision

Keep `MultiAgentCrossReview` public, but limit it to framework files, templates, tools, and sanitized examples.

Move real mutable workbench state through WorkbenchStateSync:

- `UserSettings/**/*.md`
- `Projects/<name>/RULES.md`
- `Reviews/<review-id>/**`

Keep raw session JSONL separate under session transport tooling.

Rename the standalone sync tool repository to `MultiAgentWorkbenchStateSync` so the repository name matches the broader state-sync role.
