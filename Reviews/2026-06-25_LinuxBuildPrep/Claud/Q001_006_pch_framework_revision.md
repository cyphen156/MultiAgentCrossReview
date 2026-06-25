Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: Callbacks/Q001_C002_user.md
Supersedes: Claud/Q001_005_p1_dropin.md 의 §1 (pch.h 가드 방식)
Status: Implementation-Draft
Baseline: 2026-06-25 sync. 워크벤치 읽기 전용 → 드롭인 초안. 원본 적용·빌드·커밋은 사용자.

# P1 §1 수정 — crtdbg를 framework.h Windows 경계로 이동

C002 반영: pch.h는 인라인 가드를 갖지 않는다. 디버그 힙(crtdbg) 블록은 이미 플랫폼 분기점인
framework.h 안으로 내려 **Windows 경계 코드**가 되고, Linux 분기에 대응 경계(placeholder)를 둔다.
plat 분기 단독 소유점 = framework.h.

§2(PlatformDebugOutput shim) / §3(호출 치환)은 Q001_005 그대로 유효.

## 1. pch.h 전체 교체 (가드 제거, 순수 조립)

`Source/pch.h`:

```cpp
#pragma once
#ifndef PCH_H
#define PCH_H

// 커스텀 필수 헤더
// 플랫폼 매크로 확정 → 플랫폼 컴파일 환경(시스템 헤더 / 디버그 힙 / OS 타입) → 공통 정의
#include "Build/Public/PlatformDefine.h"
#include "Build/Public/framework.h"
#include "Build/Public/define.h"

#endif // PCH_H
```

변경점: 기존 `_DEBUG` crtdbg 블록 삭제(→ framework.h로 이동). pch.h는 더 이상 MSVC/플랫폼
세부를 알지 않는다.

## 2. framework.h 전체 교체 (Windows 경계로 흡수 + Linux 경계 추가)

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

#elif PLATFORM_LINUX

#include <cstdint>

using LARGEINTEGER = int64_t;

// Linux 디버그 힙(메모리 누수 추적) 경계입니다.
// crtdbg 등가물이 없으므로 현재는 비워 둡니다. 누수 추적은 ASan / valgrind 등
// 외부 도구 또는 추후 Platform/Linux 메모리 진단 계층에서 다룹니다.
#ifdef _DEBUG
	// (의도적 비움 — #3 또는 Diagnostics 단계에서 확정)
#endif

#elif PLATFORM_ANDROID

#error "Android framework is not implemented."

#elif PLATFORM_MAC

#error "Mac framework is not implemented."

#else

#error "Unsupported platform."

#endif
```

## 근거 / 검증 포인트

- **순서 보존**: crtdbg 블록을 PLATFORM_WINDOWS 분기 **맨 앞**(Windows.h 이전)에 둬 기존 pch
  순서(crtdbg → 그 외)와 동일한 매핑 범위를 유지. 회귀 위험 최소.
- **PLATFORM_WINDOWS 가시성 확보**: framework.h는 PlatformDefine.h를 먼저 포함하므로 분기 매크로가
  유효(기존 pch에선 crtdbg가 PlatformDefine보다 앞서 PLATFORM_*를 못 봤던 문제 해소).
- **`_DEBUG`는 cross-platform 디버그 판별자로 유지** — Linux 디버그 빌드도 `_DEBUG` 주입 시 동일 분기
  진입, 단 Windows crtdbg는 비활성(빈 경계). 다른 `#ifdef _DEBUG`(Renderer.cpp 등) 무영향.
- **pch.h 단순화**: 플랫폼/MSVC 세부를 framework.h가 단독 소유 → pch는 조립만.

## 합격 기준 (변경 없음)
- Windows Debug에서 crtdbg 누수 추적 동작 동일(회귀 없음), Release 무영향.
- 공통 .h/.cpp에 PLATFORM_WINDOWS 가드 밖 Win API 0(Windows leaf 제외).
