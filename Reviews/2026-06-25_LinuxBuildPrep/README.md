# Linux Build Prep (#2_7) 검토 요약

> 이 파일만 **가변**(현재 상태 요약). 독립 판단·교차검증·수정 결론·증거 확인은 append-only.

- **질문**: #2_6 마감 후 #2_7 플랜 + Linux 빌드 작업의 브랜치 귀속(#2 마감 vs #3 이동). (Questions/Q001.md)
- **범위**: P1 공통 계층 Win 누수 봉합 + P2 CMake 빌드 시스템 도입(공통 코어 Linux 컴파일 통과).
- **제외**: Platform/Linux 실구현(dlopen/POSIX/EGL), Linux 표시, 통합 테스트(→#3), ResourceManager/Mesh(→Linux 확인 이후).
- **Baseline**: 2026-06-25 sync (#2_6 마감, devlog 26.06.24.txt)

## 현재 결론 (확정)

**#2_7 = P1~P2로 #2 마감.** 경계선 = "Linux에서 컴파일된다"(링크 미해결 심볼 = #3 시작점).
Linux 실구현·표시·통합 테스트는 **#3(로드맵 B3)**. 상세는 Decision/Q001_decision.md.

P1 감사 핵심: framework.h/PlatformDefine.h가 이미 PLATFORM_* 분기 보유(설계 선반영). 남은 누수 = pch.h `_DEBUG` MSVC 블록 + OutputDebugStringA 4곳뿐.

## 기록 인덱스

| # | 파일 | Author | Responds-To | Status |
|---|---|---|---|---|
| 001 | Questions/Q001.md | User | none | Open |
| 002 | Claud/Q001_001_plan_and_boundary.md | Claude | Q001 + devlog 26.06.24 | Plan-Draft |
| 003 | Callbacks/Q001_C001_user.md | User | Q001_001 (5절) | Callback |
| 004 | Decision/Q001_decision.md | Claude(통합)+User | Q001_001 + C001 | Decision |
| 005 | Claud/Q001_005_p1_dropin.md | Claude | Decision(P1) + 사용자 "P1부터" | Implementation-Draft |
| 006 | Callbacks/Q001_C002_user.md | User | Q001_005 §1(pch.h) | Callback |
| 007 | Claud/Q001_006_pch_framework_revision.md | Claude | Q001_C002 (supersedes 005 §1) | Implementation-Draft |
| 008 | Callbacks/Q001_C003_user.md | User | Q001_005 §2(shim) | Callback |
| 009 | Claud/Q001_007_debug_macro_in_framework.md | Claude | Q001_C003 (supersedes 005 §2·§3 include) | Implementation-Draft |
| 010 | Claud/Q001_008_framework_applied_review.md | Claude | 사용자 적용 framework.h | Evidence-Check |
| 011 | Claud/Q001_009_crtdbg_order_regression.md | Claude | 사용자 적용 framework.h v2(_DEBUG 통합) | Evidence-Check |
| 012 | Claud/Q001_010_p1_complete_verification.md | Claude | P1 적용 완료 재동기화본 | Evidence-Check (P1 DONE) |
| 013 | Claud/Q001_011_p2_cmake_draft.md | Claude | Decision(P2) + 사용자 "실행파일 포함" + vcxproj | Implementation-Draft |
| 014 | Claud/Q001_012_p2_windows_build_pass.md | Claude | 사용자 CMake 빌드 결과(Windows) | Evidence-Check (P2 Win PASS) |
| 015 | Claud/Q001_013_close_and_output_standardize.md | Claude | 사용자 결정(Linux→#3 + 산출물 규격화) | Decision-Followup |
| 016 | Claud/Q001_014_cmake_linux_only_role.md | Claude | 사용자 결정(Windows=MSVC, CMake=Linux 전용) | Decision-Followup |
| 017 | Claud/Q001_015_output_scheme_aligned.md | Claude | 사용자 CyphenBuild.props 공유 | Implementation-Draft |

## 진행 상태

- **P1 ✅ 완료 (적용·검증 PASS, Q001_010)**:
  - pch.h 순수 조립화 + **framework.h 단독 분기 소유**(crtdbg Win 경계 + Linux 경계 placeholder + 디버그 출력 매크로 **`PRINT_DEBUG_OUTPUT`** Win=OutputDebugStringA/Linux=fputs).
  - framework.h 순서 교정 반영(`_CRTDBG_MAP_ALLOC`<crtdbg.h, targetver<Windows.h).
  - 호출부 ~14곳 `OutputDebugStringA`→`PRINT_DEBUG_OUTPUT`, 전부 `#ifdef _DEBUG` 내부. 테스트도 `#if PLATFORM_WINDOWS`→`#ifdef _DEBUG` 전환.
  - 폐기: `PlatformDebugOutput.h`/inline 함수 — 미생성.
- **P2 (산출물 완성, 적용·검토 대기, Q001_011)**: 루트 `CMakeLists.txt` — Application(exe) 타깃, include 루트 Source, 공통/Windows/Linux 소스 분리, 구성별 `_DEBUG`/`NDEBUG` 전 플랫폼 공통, Windows-leaf(WindowsJpegCodec/.rc/Platform/Windows) 격리, Linux Threads/dl 링크, CoreIo 리소스 복사 패리티. PCH는 CMake 미사용(각 TU `#include "pch.h"` 의존). Linux 링크 갭(ModuleLoader/PlatformFile/PlatformTime/main) = #3 입력.
  - 복사용 산출물: **`Claud/artifacts/CMakeLists.txt`**. 참조 소스 26개 경로 **존재 검증 통과**(MISSING 0).
  - 대조 필요: `CyphenBuild.props`(C++표준/출력/정의).

## 최종 판정

확정 (Decision/Q001_decision.md). Codex 부재일 → Claude 단독 기획 + 사용자 확정, 교차검증 단계 없음.
