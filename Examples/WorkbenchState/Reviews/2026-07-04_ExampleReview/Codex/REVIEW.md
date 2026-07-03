Review-ID: 2026-07-04_ExampleReview
Author: Codex
Baseline: commit=0000000
Session-Id:
Status: Initial

# Review

This sanitized sample shows where Codex's mutable review record lives in the user-managed state repository.

## Findings

- `Reviews/<review-id>/` is synced state, not public framework content.
- `Reviews/README.md`, `Reviews/_TEMPLATE/**`, and `Reviews/run-review.ps1` remain public framework files.
