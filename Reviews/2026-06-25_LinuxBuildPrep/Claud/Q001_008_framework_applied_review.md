Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 적용 framework.h 붙여넣기 (검토 요청)
Supersedes: Claud/Q001_007 의 매크로명만 (PLATFORM_DEBUG_OUTPUT → PRINT_DEBUG_OUTPUT)
Status: Evidence-Check
Baseline: 2026-06-25 sync. 사용자 적용본 검토(원본 적용은 사용자).

# framework.h 적용본 검토 (PRINT_DEBUG_OUTPUT)

사용자가 P1 §1+§2를 framework.h에 적용. 매크로명을 `PRINT_DEBUG_OUTPUT`로 확정.

## 검토 결과: 기능적 PASS

- **매크로를 `<Windows.h>`/`<cstdio>` 이전에 정의해도 안전**: 매크로는 텍스트 치환 규칙이라 정의
  시점에 심볼 불요. 해석은 호출부에서 일어나고 그 시점엔 pch→framework→시스템헤더가 이미 포함됨.
- **crtdbg 순서 보존**: `#define new`가 Windows.h 이전 — 기존 pch.h 순서와 동일, 매핑 범위/회귀 없음.
- **타입 별칭**: Windows LARGE_INTEGER(Windows.h 뒤) / Linux int64_t(cstdint 뒤) 정상.
- **ANDROID/MAC**: `#error` 선행으로 매크로 미정의 무해.

## 적용 확정 사항

- 디버그 출력 매크로명 = **`PRINT_DEBUG_OUTPUT(text)`**
  - Windows: `OutputDebugStringA(text)`
  - Linux:   `std::fputs((text), stderr)`
- crtdbg(Windows 디버그 힙) + 디버그 출력 매크로 모두 framework.h 단독 소유.
- pch.h는 순수 조립(Q001_006 §1) — 별도 `PlatformDebugOutput.h` 미생성(Q001_007 폐기 유지).

## §3 호출부 치환 (확정 대상명 갱신)

`OutputDebugStringA(x)` → `PRINT_DEBUG_OUTPUT(x)`, include 불요:
- Renderer.cpp:264 / CyphenEngine.cpp:97,108,174,212(190 주석) / CoreIOTests.cpp:25,26,40,48 /
  ModuleTest.cpp:54,61,62,76,84

## 소소한 정리 권고 (컴파일 무관, 선택)
1. 탭/스페이스: Linux 분기 매크로도 탭으로 맞춰 두 분기 정렬 일관화.
2. (취향) Windows 매크로 위치를 경계 항목(using LARGEINTEGER 부근)으로 그룹화 가능 — 동작 영향 0.

## 미반영 시 영향
- 없음(현 적용본 그대로 Windows 빌드 정상, Linux 분기 well-formed). 권고 1·2는 미관/일관성뿐.
