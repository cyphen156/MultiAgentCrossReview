# MultiAgentCrossReview Project Rules Example

This sanitized file represents a synced `Projects/<name>/RULES.md` entry.

## Boundary

- Keep public process and template files in `MultiAgentCrossReview`.
- Keep real review records in the configured state repository.
- Keep raw session JSONL outside WorkbenchStateSync.

## Review Records

- Use one mutable `REVIEW.md` per agent.
- Use one mutable `DECISION.md` for the user decision.
- Preserve history through git commits in the state repository.

## Public Examples

- Public examples must be sanitized.
- Public examples belong under `Examples/`, not under real `Reviews/<review-id>/` paths.
