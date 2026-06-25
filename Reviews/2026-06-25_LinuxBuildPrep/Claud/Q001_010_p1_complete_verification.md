Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 적용 완료(framework.h 순서 교정 + 테스트 #if PLATFORM_WINDOWS→#ifdef _DEBUG+PRINT_DEBUG_OUTPUT 전환) 재동기화 검토
Supersedes: none
Status: Evidence-Check
Baseline: 2026-06-25 재동기화본. P1 적용 완료 검증.

# P1 완료 검증 — PASS

재동기화본 미러 기준 전수 확인. #2_7 P1(공통 계층 Win 누수 봉합) 적용 완료.

## 검증 항목

- **framework.h 순서 교정(전 회귀 2건 해소)**:
  - `#define _CRTDBG_MAP_ALLOC` → `#include <crtdbg.h>` **이전**으로 복구(디버그 힙 malloc file/line 매핑 복구).
  - `targetver.h` → `<Windows.h>` **이전**으로 복구(OS 버전 타게팅 복구).
- **crtdbg + PRINT_DEBUG_OUTPUT** 모두 framework.h `#ifdef _DEBUG` 플랫폼 분기에 흡수. pch.h 순수 조립.
- **원시 `OutputDebugStringA` 제거**: framework.h 매크로 정의 외 잔존 = `CyphenEngine.cpp:190` **주석 1줄**(무관).
- **매크로 호출 전수 `#ifdef _DEBUG` 내부**(불변식 C 충족):
  - CyphenEngine.cpp 97,108(71–144) / 174(173–175) / 212(179–217)
  - Renderer.cpp 264(_DEBUG FPS 블록)
  - CoreIOTests.cpp 25,26,39,46 / ModuleTest.cpp 54,61,62,76,84 (각 `#ifdef _DEBUG`)
- **테스트 전환 확인**: 기존 `#if PLATFORM_WINDOWS` 가드 → `#ifdef _DEBUG` + `PRINT_DEBUG_OUTPUT`.
  원시 `OutputDebugStringA` 미잔존 → Linux 디버그 빌드 안전.
- **PLATFORM_WINDOWS 과치환 없음**: 잔존 전부 정상 분기(framework.h:14, define.h:56, CChar.h:69,
  BuildInfo.h:41, PlatformDefine.h machinery). 디버그 출력용 플랫폼 가드만 _DEBUG로 전환됨.

## 결론

P1 = 완료. Linux 안전성: Debug→`std::fputs(stderr)`, Release→호출 컴파일 아웃, 매크로 게이트=호출 게이트 일치.
잔여(선택): `CyphenEngine.cpp:190` 주석을 `PRINT_DEBUG_OUTPUT` 표기로 정렬(동작 무관).

→ 다음: P2 (CMake 빌드 시스템 도입 + TARGET_PLATFORM_LINUX + Windows-only leaf 분리).
