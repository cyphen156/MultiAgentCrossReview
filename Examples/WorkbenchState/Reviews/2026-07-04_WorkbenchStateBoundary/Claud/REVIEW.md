Review-ID: 2026-07-04_WorkbenchStateBoundary
Author: Claude
Baseline: public-framework-boundary
Session-Id:
Status: Evidence-checked

# Review

## Judgment

The public repository should keep only the framework, templates, runner scripts, and sanitized examples. Real review instances are user state and should be synced through a separate state repository.

## Evidence

- Real review records contain user callbacks, agent reasoning, candidate artifacts, and project-specific context.
- The public repository can still explain the workflow with sanitized examples under `Examples/`.
- `Reviews/<review-id>/` paths are operational state, not framework documentation.

## Risk

If examples are placed under real `Reviews/<review-id>/` paths, readers may copy that as the normal public layout and future real review records may be committed by mistake.
