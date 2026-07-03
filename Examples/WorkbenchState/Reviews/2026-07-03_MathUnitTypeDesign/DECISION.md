---
Review-ID: 2026-07-03_MathUnitTypeDesign
Author: User
Baseline: 2026-07-02T19:09 sync | commit=4d6925d Source=94
Status: Decided
---

# DECISION - #4 Math, unit, and coordinate type design

## Decision

MERGE

- Adopt the converged Codex/Claude shape: `class Math final` as a narrow stateless static utility, with data-carrying value types kept separate.
- Math is not a runtime module. It belongs under the Core compile-time foundation, initially `Core/Public/Math/`.
- The first deliverable is the unit/coordinate/type contract before broad API growth.
- Default world coordinate basis:
	- Origin: lower-left.
	- +X: right.
	- +Y: up.
	- +Z: forward/depth.
	- Handedness: left-handed when +Z means forward into the world.
- Reference model:
	- UE differs in axis naming: `+X forward`, `+Y right`, `+Z up`.
	- Unity matches the selected CyphenEngine user-intuition model: `+X right`, `+Y up`, `+Z forward`.
	- CyphenEngine follows the Unity-style axis model for the default world rule.
- #4_1 scope:
	- Land only the world coordinate and origin/basis decision.
	- Defer `Math`, `Mathf`, `Vector`, `Vector2D`, precision, SIMD, and overload API details to the next work unit.

## Rationale

The user chooses a user-intuition-first default coordinate system. Jumping upward should increase Y, horizontal movement to the right should increase X, and depth/forward movement should increase Z. This keeps 2D world work natural on the XY plane while preserving a direct extension path to 3D.

Renderer API clip/projection differences remain outside the world rule and are handled later at the renderer/projection boundary. Math and vector API details are intentionally not part of this #4_1 decision.

## Application

No source repo application yet. Codex edit-copy proposal created `CyphenEngine/DevLog/Decisions.txt` with `CyphenEngine_World_Rule` as the first persisted world-coordinate decision. No Math/Vector source implementation is part of #4_1.
