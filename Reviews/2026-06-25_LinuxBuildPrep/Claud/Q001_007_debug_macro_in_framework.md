Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: Callbacks/Q001_C003_user.md
Supersedes: Claud/Q001_005_p1_dropin.md 의 §2(PlatformDebugOutput.h shim) + §3의 include 부분
Status: Implementation-Draft
Baseline: 2026-06-25 sync. 워크벤치 읽기 전용 → 드롭인 초안. 원본 적용·빌드·커밋은 사용자.

# P1 §2 수정 — 디버그 출력을 framework.h 플랫폼 매크로로 흡수

C003 반영: 별도 `PlatformDebugOutput.h` 와 inline 함수를 만들지 않는다. crtdbg와 동일하게
framework.h 플랫폼 분기가 **디버그 출력 매크로**를 소유한다. 호출부는 함수명만 매크로로 치환 →
기존 코드 형태 보존. nullptr 가드 없음 = 기존 `OutputDebugStringA` 동작과 정확히 동일.

이 기록으로 framework.h 최종형(§1 crtdbg + §2 매크로 통합)을 고정한다.

## framework.h 전체 교체 (crtdbg + 디버그 출력 매크로 통합 최종형)

`Source/Build/Public/framework.h`:

```cpp
#pragma once

// ============================================================================
// Framework
// ----------------------------------------------------------------------------
// 선택된 PLATFORM_* 기준으로 플랫폼별 컴파일 환경을 준비합니다.
//
// - 플랫폼 시스템 헤더 포함
// - 플랫폼별 OS 타입 규약 확정
// - 플랫폼별 디버그 힙(메모리 누수 추적) 경계
// - 플랫폼별 디버그 출력 경계
// ============================================================================

#include "Build/Public/PlatformDefine.h"

#if PLATFORM_WINDOWS

// Windows 디버그 힙(메모리 누수 추적) 경계입니다.
// _CRTDBG_MAP_ALLOC 정의와 crtdbg.h 포함은 다른 시스템 헤더보다 앞서야
// new/malloc 매핑이 전체 변환 단위에 적용됩니다.
#ifdef _DEBUG
	#define _CRTDBG_MAP_ALLOC
	#include <crtdbg.h>
	#define new new(_NORMAL_BLOCK, __FILE__, __LINE__)
#endif

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN

#include "Platform/Windows/Public/targetver.h"
#include <Windows.h>

using LARGEINTEGER = LARGE_INTEGER;

// 플랫폼 디버그 출력 경계입니다. UTF-8 문자열을 플랫폼 디버그 채널로 그대로 씁니다.
#define PLATFORM_DEBUG_OUTPUT(text) OutputDebugStringA(text)

#elif PLATFORM_LINUX

#include <cstdint>
#include <cstdio>

using LARGEINTEGER = int64_t;

// Linux 디버그 힙(메모리 누수 추적) 경계입니다.
// crtdbg 등가물이 없으므로 현재는 비워 둡니다. 누수 추적은 ASan / valgrind 등
// 외부 도구 또는 추후 Platform/Linux 메모리 진단 계층에서 다룹니다.
#ifdef _DEBUG
	// (의도적 비움 — #3 또는 Diagnostics 단계에서 확정)
#endif

// 플랫폼 디버그 출력 경계입니다.
#define PLATFORM_DEBUG_OUTPUT(text) std::fputs((text), stderr)

#elif PLATFORM_ANDROID

#error "Android framework is not implemented."

#elif PLATFORM_MAC

#error "Mac framework is not implemented."

#else

#error "Unsupported platform."

#endif
```

## §3 갱신 — 호출 사이트 치환 (include 불요)

framework.h는 pch.h가 전역 포함하므로 매크로는 모든 TU에서 가시. **추가 include 없음.**
(Q001_005 §3의 `#include "Build/Public/PlatformDebugOutput.h"` 줄은 폐기.)

`OutputDebugStringA(x)` → `PLATFORM_DEBUG_OUTPUT(x)` 단순 치환:

- `Modules/Renderer/Private/Renderer.cpp`: 264
- `Engine/Private/CyphenEngine.cpp`: 97, 108, 174, 212 (190 주석도 표기 갱신 권장)
- `Test/CoreIO/CoreIOTests.cpp`: 25, 26, 40, 48
- `Test/Module/ModuleTest.cpp`: 54, 61, 62, 76, 84

인자(`const char*` 리터럴/버퍼) 그대로. 시그니처/호출 형태 불변, 이름만 변경.

## 폐기 항목
- `Source/Build/Public/PlatformDebugOutput.h` (Q001_005 §2) — **생성하지 않음.**
- `PlatformDebugOutputUtf8(...)` inline 함수 — 도입 안 함.

## 근거 / 검증
- **단일 분기 소유**: 디버그 힙 + 디버그 출력 모두 framework.h 플랫폼 분기에 모임. pch는 조립만.
- **기존 코드 보존**: 매크로라 호출부는 이름만 바뀜. 새 헤더/함수/가드 산포 없음.
- **동작 동일**: Windows는 OutputDebugStringA 그대로 → 출력/회귀 없음. nullptr 가드 제거로 기존과 동일.
- **Linux 즉시 컴파일·링크**: 매크로 → `std::fputs(.., stderr)`, #3 작업 불요.
- **매크로 위생**: 함수형 매크로 인자에 괄호(`(text)`) 적용. 호출부는 단일 식별자/리터럴이라 콤마 위험 없음.

## 합격 기준 (변경 없음)
- Windows Debug crtdbg 누수 추적 동작 동일, Release 무영향.
- 공통 .h/.cpp에 PLATFORM_WINDOWS 가드 밖 Win API 0(Windows leaf 제외).
- 디버그 출력 텍스트/개행 동일.

> 비고: 매크로명 `PLATFORM_DEBUG_OUTPUT`은 기존 `PLATFORM_*` 매크로 규약(UPPER_SNAKE)과 정합.
> 다른 이름 선호 시 치환만 바꾸면 됨.
