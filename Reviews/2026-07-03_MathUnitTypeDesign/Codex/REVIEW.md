---
Review-ID: 2026-07-03_MathUnitTypeDesign
Author: Codex
Baseline: 2026-07-02T19:09 sync | commit=4d6925d Source=94
Session-Id:
Status: Initial
---

# Codex REVIEW - #4 Math, unit, and coordinate type design

## 1. Initial Judgment

Position: REVISE

The user direction is correct: #4 should start with Math, coordinate units, and data types before 2D world features. The part I would revise is treating "Math class" as the whole design. The safer foundation is a small `Math` function namespace plus explicit value types and named unit/convention decisions.

### 1. Math as stateless static/final class

Recommended with a narrow meaning.

Use `Math` as a non-instantiable, stateless utility surface for scalar operations and constants:

- `Abs`, `Min`, `Max`, `Clamp`, `Lerp`, `Saturate`
- `Sin`, `Cos`, `Tan`, `Sqrt` wrappers only if the engine wants one naming/type policy
- constants such as `Pi`, `HalfPi`, `DegToRad`, `RadToDeg`

Do not put every vector/matrix operation only on `Math`. Value-type behavior should live with the value type when it is intrinsic and readable:

- `Vector2::Length`
- `Vector2::Normalized`
- `Matrix3x2::Identity`
- `Rect::Contains`

This keeps `Math` stateless without creating a god utility class.

For C++, "static final class" should be translated into one of these local-style options:

- `class Math final` with deleted constructor/destructor/copy and only static members.
- `namespace Math` if the project accepts namespaces for pure function groups.

Given existing engine style appears class-heavy for public APIs, `class Math final` is acceptable, but it should remain very small.

### 2. Modularization

Do not make Math a runtime module at the first patch.

Math should be a foundational compile-time layer, likely under Core ownership, because it must be usable by Engine, Runtime, Editor, Renderer, Resource, and future World code without dynamic module loading or ABI concerns. A separate runtime module for Math would make the lowest-level dependency heavier than its callers.

Recommended first boundary:

- `CyphenEngine/Source/Core/Public/Math/` for public primitives and functions.
- `CyphenEngine/Source/Core/Private/Math/` only when implementation is too large for headers.

If the project later needs SIMD/platform specializations, that can become a private implementation boundary or Build/platform policy, not a first-class renderer-style module.

### 3. Other Recommended Option

Start with "unit and convention contract" before a broad Math API.

For #4 2D world work, the first design document/patch should answer:

- Scalar type: prefer `float32`/`float` for world/render math unless the project has a reason to use double precision.
- Angle unit: radians internally; degree helpers only at API edges or editor-facing input.
- Pixel vs world unit: do not silently mix them. Use names that reveal the unit, such as `PixelSize`, `WorldPosition2`, or at least separate aliases/types if the engine can support them cheaply.
- Coordinate handedness and screen origin: document whether 2D world uses +X right, +Y up or +Y down, and where renderer/UV conversion happens.
- Transform shape: for 2D, begin with `Vector2`, `Size2`, `Rect`, and `Transform2D`; defer general `Vector3`, quaternion, and 4x4 matrix unless needed immediately.

First patch should be intentionally small:

1. Add Math folder and type/convention comments.
2. Add scalar aliases only if they do not duplicate existing primitive types.
3. Add `Math` constants/functions and `Vector2`/`Size2`/`Rect` minimal value types.
4. Add tiny tests for clamp/lerp/vector/rect behavior.

This creates a usable base without locking the whole 2D world architecture too early.

## 2. Cross-Review Against Claude REVIEW

`Claud/REVIEW.md` is not written yet.

Verdict: PENDING

## 3. Revised Conclusion

Pending Claude review and user decision.

Position: KEEP

## 4. Evidence Check

Evidence-Status: PARTIAL

- `Projects/CyphenEngine/RULES.md`: #4 is the current 2D world development work unit; project architecture keeps foundational layers under Build/Core/HAL/Platform before Engine/Runtime/Editor/Modules.
- `Projects/CyphenEngine/baseline`: search found no established Math/Vector class layer yet.
- `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/2026/26.07.01.txt`: previous Vulkan note records coordinate/UV orientation differences, so coordinate convention should be made explicit before more renderer/world work.
