Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: Decision/Q001_decision.md (P1) + 사용자 "P1부터 가자"
Supersedes: none
Status: Implementation-Draft
Baseline: 2026-06-25 sync. 워크벤치 읽기 전용 → 드롭인 초안. 원본(C:\Project\CyphenEngine) 적용·빌드·커밋은 사용자.

# #2_7 P1 드롭인 — 공통 계층 Win 누수 봉합

스타일: Allman, 탭, 람다 금지. 정식 Logger/Diagnostics sink 아님(Todos 4로 이월) — 기존 raw
`OutputDebugStringA` 호출을 플랫폼 독립으로 만드는 최소 경유점만 둔다.

## 봉합 대상 (감사 결과)

- `pch.h` `_DEBUG` 블록: `_CRTDBG_MAP_ALLOC` / `<crtdbg.h>` / `#define new` — MSVC 전용, 플랫폼 가드 없음.
  추가로 이 블록이 `PlatformDefine.h` 포함 **이전**에 있어 PLATFORM_WINDOWS를 못 본다 → 순서도 교정.
- `OutputDebugStringA` 직접 호출 (Win 전용 API):
  - `Modules/Renderer/Private/Renderer.cpp`:264
  - `Engine/Private/CyphenEngine.cpp`:97, 108, 174, 212 (190은 주석)
  - `Test/CoreIO/CoreIOTests.cpp`:25, 26, 40, 48
  - `Test/Module/ModuleTest.cpp`:54, 61, 62, 76, 84

> `RenderCommand.h`의 "d3d11"은 주석뿐 — 봉합 불필요.

## 1. pch.h 재정렬 + 가드

`Source/pch.h` 전체 교체:

```cpp
#pragma once
#ifndef PCH_H
#define PCH_H

// 플랫폼 매크로를 먼저 확정한다.
// (crtdbg 등 MSVC 전용 블록을 PLATFORM_WINDOWS로 가드하려면 선행 포함이 필요하다.)
#include "Build/Public/PlatformDefine.h"

#if PLATFORM_WINDOWS && defined(_DEBUG)
	#define _CRTDBG_MAP_ALLOC
	#include <crtdbg.h>
	#define new new(_NORMAL_BLOCK, __FILE__, __LINE__)
#endif

// 커스텀 필수 헤더
#include "Build/Public/framework.h"
#include "Build/Public/define.h"

#endif // PCH_H
```

핵심: `_DEBUG`는 cross-platform 디버그 빌드 판별자로 유지(Renderer.cpp `#ifdef _DEBUG` 등 그대로),
**MSVC 전용 crtdbg/`#define new`만** PLATFORM_WINDOWS로 격리. `framework.h`는 자체 `#pragma once`라
PlatformDefine 중복 포함 무해.

## 2. PlatformDebugOutput shim (헤더-온리)

신규 `Source/Build/Public/PlatformDebugOutput.h`:

```cpp
#pragma once

#include "Build/Public/framework.h"   // PLATFORM_* 확정 + (Windows: <Windows.h>)

#if PLATFORM_LINUX
#include <cstdio>
#endif

// ============================================================================
// PlatformDebugOutput
// ----------------------------------------------------------------------------
// 플랫폼 디버그 출력 채널에 UTF-8 문자열을 그대로 쓰는 얇은 portability shim입니다.
//
// 책임:
//   - PLATFORM_WINDOWS: OutputDebugStringA로 디버거 출력 창에 기록
//   - PLATFORM_LINUX  : stderr로 기록
//
// 비책임:
//   - 포맷팅 / 심각도 / 큐 / LogRecord (정식 Logger/Diagnostics는 Todos 4 단계)
// ============================================================================

inline void PlatformDebugOutputUtf8(const char* utf8Text)
{
	if (utf8Text == nullptr)
	{
		return;
	}

#if PLATFORM_WINDOWS
	OutputDebugStringA(utf8Text);
#elif PLATFORM_LINUX
	std::fputs(utf8Text, stderr);
#endif
}
```

`inline` 함수라 다TU ODR-safe, .cpp 불요. Linux에서 #3 작업 없이 컴파일·링크됨(Win.h는 PLATFORM_WINDOWS
가드 안에서만 참조, Linux는 fputs).

## 3. 호출 사이트 치환

각 파일에 include 추가 후 `OutputDebugStringA(x)` → `PlatformDebugOutputUtf8(x)`.

```cpp
#include "Build/Public/PlatformDebugOutput.h"
```

- `Renderer.cpp`: 264  `OutputDebugStringA(message);` → `PlatformDebugOutputUtf8(message);`
- `CyphenEngine.cpp`: 97/108/174/212 동일 치환. (190 주석도 동일 표기로 갱신 권장)
- `CoreIOTests.cpp`: 25/26/40/48 동일 치환.
- `ModuleTest.cpp`: 54/61/62/76/84 동일 치환.

치환은 인자 그대로(이미 `const char*` UTF-8 버퍼/리터럴) — 시그니처 변화 없음.

## 합격 기준 (P1)

- 공통 `.h/.cpp`에 PLATFORM_WINDOWS 가드 밖 Win API 참조 0 (Windows leaf=WindowsJpegCodec 제외).
- Windows Debug/Release 빌드 회귀 없음(OutputDebugString 출력 동일, crtdbg 동작 동일).
- 치환 후 디버그 출력 텍스트/개행 동일.

## 미해결 / 후속
- 정식 sink(LogRecord/큐/심각도)는 Todos 4 Logger 단계에서 PlatformDebugOutputUtf8를 흡수.
- P2(CMake)에서 이 shim은 공통 코어 타깃에 그대로 포함(플랫폼 분기 헤더-온리).
