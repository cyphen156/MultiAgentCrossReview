Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 적용 framework.h v2 (PRINT_DEBUG_OUTPUT을 #ifdef _DEBUG 내부로 통합) 검토 요청
Supersedes: none (Q001_008 검토에 회귀 2건 추가 발견)
Status: Evidence-Check
Baseline: 2026-06-25 sync. 사용자 적용본 검토(원본 적용은 사용자).

# framework.h v2 검토 — _DEBUG 내부 통합 시 순서 회귀 2건

매크로를 `#ifdef _DEBUG` 안으로 통합한 발상은 수용 가능(불변식 C 전제). 단 재배치에서 순서 회귀 2건 발생.

추가 확인: 테스트(CoreIOTests/ModuleTest)는 이미 `#if PLATFORM_WINDOWS`로 직접 가드(매크로 미사용).
→ `PRINT_DEBUG_OUTPUT` 사용처 = Renderer.cpp / CyphenEngine.cpp 의 `#ifdef _DEBUG` 블록뿐.

## 🔴 A. `_CRTDBG_MAP_ALLOC`가 `#include <crtdbg.h>` 뒤 — 실질 버그(회귀)

```c
#ifdef _DEBUG
#include <crtdbg.h>          // crtdbg 이미 처리
#define PRINT_DEBUG_OUTPUT(text) OutputDebugStringA(text)
#define _CRTDBG_MAP_ALLOC    // 너무 늦음 → no-op
#define new new(_NORMAL_BLOCK, __FILE__, __LINE__)
#endif
```

MS 규약: `_CRTDBG_MAP_ALLOC`은 **crtdbg.h 포함 이전**에 정의해야 malloc/calloc/free 등이 file/line
추적 디버그 버전으로 매핑됨. 현 순서면 매핑 미설치 → **디버그 힙 누수 추적(malloc 계열) 꺼짐.**
`#define new`만 남아 new 추적만 유지 → #2_6 빌드 대비 회귀.

## 🟠 B. `<Windows.h>`가 `targetver.h` 앞 — 회귀

```c
#include <Windows.h>                            // 버전 미설정 상태로 파싱
#include "Platform/Windows/Public/targetver.h"  // 너무 늦음
```

`targetver.h`(=`_WIN32_WINNT`/SDKDDKVer)는 타깃 OS 버전 확정 → 반드시 Windows.h 이전. 현 순서는
버전 타게팅 무효(기본값 컴파일). 컴파일은 되나 의도 API 레벨 미적용 잠재 회귀.

## 🟡 C. 불변식(버그 아님): 매크로가 `_DEBUG`에서만 정의됨

모든 `PRINT_DEBUG_OUTPUT` 호출이 `#ifdef _DEBUG` 안에 있어야 함. 현재 충족.
선택적 Release 안전망: `_DEBUG` 밖에
`#ifndef PRINT_DEBUG_OUTPUT` / `#define PRINT_DEBUG_OUTPUT(text) ((void)0)` / `#endif`
를 두면 미가드 호출도 무해. (강제 아님 — 사용자 "디버그 레이아웃 통합" 의도와 trade-off)

## 교정안 (Windows 블록)

```c
#if PLATFORM_WINDOWS

#ifdef _DEBUG
#define _CRTDBG_MAP_ALLOC                             // crtdbg.h 보다 먼저
#include <crtdbg.h>
#define new new(_NORMAL_BLOCK, __FILE__, __LINE__)
#define PRINT_DEBUG_OUTPUT(text)	OutputDebugStringA(text)
#endif

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN

#include "Platform/Windows/Public/targetver.h"        // Windows.h 보다 먼저
#include <Windows.h>

using LARGEINTEGER = LARGE_INTEGER;
```

Linux 블록: `<cstdint>`가 `_DEBUG` 밖 → LARGEINTEGER 정상. 매크로/`<cstdio>`가 `_DEBUG` 안인 것은
불변식 C와 정합. 그대로 유지 가능.

## 합격 기준 재확인
- A 교정 후 Windows Debug 힙 추적(malloc file/line) 복구.
- B 교정 후 의도 OS 버전 타게팅 복구.
- PRINT_DEBUG_OUTPUT 호출은 전부 `#ifdef _DEBUG` 내부 유지(불변식 C).
