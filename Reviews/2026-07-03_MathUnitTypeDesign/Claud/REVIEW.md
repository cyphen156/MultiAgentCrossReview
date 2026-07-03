---
Review-ID: 2026-07-03_MathUnitTypeDesign
Author: Claude
Baseline: 2026-07-02T19:09 sync | commit=4d6925d Source=94
Session-Id: workbench-claude-2026-07-03
Status: Cross-reviewed
---

# Claude REVIEW - #4 Math, unit, and coordinate type design

Transparency note: this review was written inside the workbench Claude session, which
had already read `Codex/REVIEW.md` in the same session. It is not a blind independent
judgment. Its value is evidence verification and engine-specific rulings, not procedural
independence. Section 1 still records my genuine design reasoning; Section 4 records what
was actually checked against baseline.

## 1. Initial Judgment

Position: REVISE

The user direction is correct and, importantly, already ahead of the "Math class is the
whole design" trap: the user explicitly stated the foundation is (a) base unit-system for
coordinates and (b) data-type design first. So the review should confirm that instinct and
spend its effort on the *contract specifics*, not on relitigating whether Math is one god
class.

### Q1. Math as stateless static/final class

Recommended, and now evidence-backed rather than assumed.

`class Math final` with only `static` members is the correct shape because it matches the
engine's existing stateless-utility precedent exactly (`Path.h:19` -> `class Path final`
with `static CString Combine(...)`). My initial instinct was `namespace Math`, on
DOD/no-interface grounds. I withdraw it: the baseline already answered this question with
`Path`, and consistency with the established Core utility form outweighs the namespace
purity argument. One engine can only have one answer to "how do we spell a stateless
utility," and it already picked `class ... final`.

Two refinements on top of Codex:

- Match the `Path` ctor policy verbatim. `Path` is `class Path final` with static methods;
  it does not appear to spell out deleted ctor/dtor/copy. Do not add deleted-constructor
  ceremony to `Math` that `Path` does not have. Consistency with precedent > Java-style
  non-instantiable ceremony.
- Split into two different animals, not one:
  - `class Math final` = stateless scalar utility (Abs/Min/Max/Clamp/Lerp/Saturate,
    Sin/Cos/Sqrt policy wrappers, Pi/DegToRad/RadToDeg constants). Same category as `Path`.
  - `Vector2` / `Size2` / `Rect` = real value types that carry data. These are `struct`s
    with members and intrinsic methods (`Vector2::Length`, `Rect::Contains`). They are NOT
    static-only, and they do NOT belong inside `Math`. Putting value-type behavior on `Math`
    would be the god-class mistake.

### Q2. Modularization

Strong agree with Codex: do not make Math a runtime module.

Math is a compile-time Core floor. It must be linkable by Engine / Runtime / Editor /
Renderer / Resource / World with zero ABI or dynamic-load cost. The engine's own binding-
time rule settles this: Modules exist for behavior that varies and binds at runtime; Math
never varies at runtime. It sits beside `Path` in `Core/Public`, as a plain static-linked
utility, not a module.

- `CyphenEngine/Source/Core/Public/Math/` for the public primitives and functions.
- `CyphenEngine/Source/Core/Private/Math/` only if an implementation outgrows its header.
- Future SIMD/platform specialization is a Build-time concrete-selection concern (the
  engine's build-abstraction pattern), NOT a renderer-style runtime module.

### Q3. Other recommended option — elevate the unit/coordinate contract to first deliverable

Codex filed this as "option 3." I promote it to priority #1, because it *is* what the user
asked for ("좌표계를 위한 기본단위계 설정, 자료형 설계가 기본"). Concrete rulings:

- Scalar type: single-precision `float` (or the project's existing 32-bit scalar alias if
  one exists) for world/render math. Do NOT introduce a `CFloat`. The `C~` prefix is
  policy-only: it marks types where the engine absorbs a platform/build difference into one
  common rule. IEEE-754 `float` has no such difference to absorb (same reasoning that keeps
  a raw octet as `uint8` instead of `CByte`), so scalar stays raw `float`.
- Angle unit: radians internally, everywhere. Degree helpers live only at API edges /
  editor-facing input, as explicit `DegToRad` conversions.
- Pixel vs world unit: never silently mix. At minimum name the unit at the call site
  (`WorldPosition2` vs `PixelSize`); a distinct type is better if it is cheap.
- Coordinate handedness: pick one world convention (I recommend +X right, +Y up as the math
  convention) and keep the *value types handedness/flip-neutral in their data*. The +Y-down
  screen flip and the Dx11-vs-Vulkan clip-space Z/UV differences belong at the renderer
  projection/UV seam, NOT baked into Core Math types. Evidence: the 26.07.01 DevLog already
  recorded Vulkan UV-orientation divergence, so this seam is real and must not leak upward.
- First 2D type set: `Vector2`, `Size2`, `Rect`, `Transform2D`. Defer `Vector3`, quaternion,
  4x4 until a concrete need appears.

First patch, intentionally small: (1) `Core/Public/Math/` folder + a short convention header
documenting the rulings above; (2) `class Math final` constants + scalar functions;
(3) `Vector2` / `Size2` / `Rect` minimal value structs; (4) tiny clamp/lerp/vector/rect
tests. Transform2D can follow once Vector2/Rect are stable.

## 2. Cross-Review Against Codex REVIEW

Verdict: AGREE (with two objections)

Agreements: Math = narrow stateless utility, value types separate, no runtime module, Core
placement, radians-internal, small first patch. Same destination.

Objections:

1. Codex prescribed a deleted ctor/dtor/copy "non-instantiable" ceremony. Baseline `Path`
   does not do that. Follow the actual precedent, not the textbook form.
2. Codex ranked the unit/coordinate/type contract as the third option. Given the user's own
   framing, it is the first deliverable, and Codex's evidence for the "class-heavy" shape was
   only an assumption (its own Evidence-Status: PARTIAL). I verified it against `Path.h`, so
   the shape decision is now grounded, not assumed.

## 3. Revised Conclusion

Position: REVISE

Ship the design as: `class Math final` (static scalar utility, mirroring `Path`) +
independent `Vector2`/`Size2`/`Rect`/`Transform2D` value structs, all under
`Core/Public/Math/` as a compile-time floor, and land the unit/coordinate contract header
*before* growing the API. Scalar stays raw `float` (no `CFloat`), angles radians-internal,
world types flip-neutral with the screen/clip flip isolated at the renderer seam.

## 4. Evidence Check

Evidence-Status: CONFIRMED (for shape/placement); recommendations for the contract remain
proposals not yet in baseline.

- `Core/Public/Path.h:19` — `class Path final` with `static CString` methods. Confirms the
  engine's stateless-utility form is `class ... final` + static, validating `class Math final`
  and refuting the `namespace Math` alternative.
- `baseline/.../Source` layer tree (Build/Core/HAL/Platform/Engine/Runtime/Editor/Modules) —
  confirms Math belongs in Core as a compile-time floor, not in Modules.
- Baseline search for an existing Math/Vector layer: none found. This is greenfield; no prior
  Math contract to preserve or break.
- `DevLog/2026/26.07.01.txt` (per Codex citation) — Vulkan coordinate/UV orientation
  divergence on record; supports isolating the flip at the renderer seam rather than in Core
  Math types. (Cited from Codex; not re-opened in this pass.)
- `Projects/CyphenEngine/RULES.md` — code style (Allman, tabs, LF, UTF-8 no BOM, no lambdas)
  applies to the first Math patch; work order is structure -> small reviewable patch.
