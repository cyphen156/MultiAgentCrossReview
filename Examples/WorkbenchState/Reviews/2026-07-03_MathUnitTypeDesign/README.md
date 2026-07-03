# 2026-07-03_MathUnitTypeDesign - #4 Math, unit, and coordinate type design review

> Current review state summary. Detailed agent judgments live in `Claud/REVIEW.md` and `Codex/REVIEW.md`; the final user decision lives in `DECISION.md`.

- Topic: #4 first design checkpoint for Math class shape, module boundary, base unit system, coordinate conventions, and foundational numeric/data types for 2D world development.
- Baseline commit: `2026-07-02T19:09 sync | commit=4d6925d Source=94`
- Scope: CyphenEngine #4 2D world groundwork; Math API ownership; stateless/static utility design; module or library placement; coordinate/unit naming; scalar/vector/matrix/rect/transform type boundary; first small patch direction.
- Excluded: direct source repo modification, renderer backend rewrites, physics/collision system design beyond required Math primitives, large gameplay/world architecture, final implementation patch.
- Status: Decided (world coordinate basis + Math shape/boundary fixed; pixel-vs-world type strictness and Transform2D patch timing deferred to first-patch planning)

## Current Conclusion Summary

Both agents are in and converge. The design direction is agreed; specifics were sharpened by evidence.

Convergent conclusion on the three decision points:

1. Stateless static/final Math class — YES, as `class Math final` with only static members. Verified against baseline precedent `Core/Public/Path.h:19` (`class Path final` + static methods), so this is the engine's actual stateless-utility form, not an assumption. Value types (`Vector2`/`Size2`/`Rect`/`Transform2D`) are separate data-carrying structs, NOT folded into Math.
2. Modularization — NO runtime module. Math is a compile-time Core floor at `Core/Public/Math/`, beside `Path`. SIMD/platform specialization is later a Build-time concern, not a module.
3. Better option — land the unit/coordinate contract first: scalar stays raw `float` (no `CFloat`, per C~ policy), radians internal, world types flip-neutral with the screen/clip flip isolated at the renderer seam, first types `Vector2`/`Size2`/`Rect`/`Transform2D`.

Divergence resolved: Claude withdrew an initial `namespace Math` idea after `Path.h` evidence; Claude objected to Codex's deleted-ctor ceremony (baseline `Path` has none — match precedent) and promoted the unit contract from Codex's "option 3" to first deliverable.

Open for user decision (`DECISION.md`): pixel-vs-world unit type strictness and whether Transform2D lands in patch 1 or after Vector2/Rect stabilize. Default world coordinate basis is now user-decided: lower-left origin, +X right, +Y up, +Z forward.

## Callback

- [2026-07-03] User starts #4 2D world development with Math design first. User states the foundation is base unit-system setup for coordinates and data type design, and requests agreement through the cross-review process. User asks about: (1) stateless static/final Math class shape, (2) modularization, (3) other recommended options.
- [2026-07-03] User adds that UE5 and Unity remain useful reference materials for this design. Treat them as comparison guides for coordinate/unit/API boundary decisions, not as direct patterns to copy without adapting to CyphenEngine's current Core/module architecture.
- [2026-07-03] User states CyphenEngine will still start from a Windows-family baseline and likely use a monitor-oriented coordinate intuition: X expresses left/right, Y expresses up/down, and Z expresses front/back depth. User notes this feels similar to Unity's intuition and asks whether this is a left-handed coordinate system. Pending exact sign decision: if +X is right, +Y is up, and +Z is forward into the screen/scene, the world basis is left-handed; if +Z is toward the viewer/out of the monitor, it is right-handed.
- [2026-07-03] User refines the mental model: from the perspective of "me/the object," front/back and left/right are considered before up/down. This shifts the design question away from a pure monitor-plane intuition and toward an actor/body-centric world basis like UE's "forward/right/up" framing, even if the engine may still keep Unity-like axis names for 2D convenience.
- [2026-07-03] User decides the default world coordinate system follows user intuition: origin is lower-left, +X goes right, +Y goes up, and +Z goes forward. Jumping upward should intuitively increase Y. With +Z as forward into the world, this is a left-handed world basis.
- [2026-07-03] User requests creating `DevLog/Decisions.txt` (or possibly `Rules.txt`) with `CyphenEngine_World_Rule`. Codex selected `DevLog/Decisions.txt` in the edit copy because this records a settled design decision and can later be promoted to a rules file if it grows beyond DevLog decision scope.
- [2026-07-03] User requests next work: confirm whether UE's coordinate basis differs, and if the difference is only representational, create `Vector` / `Vector2D`, split `Math` / `Mathf`, and strongly follow the Unity-style model. Codex confirmed from official docs: UE is left-handed with `+X forward`, `+Y right`, `+Z up`; Unity is left-handed with `+X right`, `+Y up`, `+Z forward`. CyphenEngine follows the Unity-style axis naming.
- [2026-07-03] Scope correction: #4_1 branch goal is only to fix the default world coordinate system and world origin/basis rule. Math/Vector implementation is deferred to a later work unit. Codex removed the edit-copy Math/Vector code that had gone beyond this scope.
- [2026-07-03] User clarifies the project standard: CyphenEngine prioritizes performance first; implementation difficulty is not the deciding concern. Therefore the default Math/Vector path should stay direct `float` for hot world math rather than adding indirection such as `MathScalar` merely for future type swapping. Double-precision variants may be added later only for concrete large-world/editor/precision needs.
- [2026-07-03] Math/Vector API details discussed here remain deferred design notes, not #4_1 implementation scope. #4_1 should land the coordinate rule first.
