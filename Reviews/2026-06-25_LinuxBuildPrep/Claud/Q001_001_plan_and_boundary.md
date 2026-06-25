Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: Q001 + devlog 26.06.24.txt "다음 작업"
Supersedes: none
Status: Plan-Draft
Baseline: 2026-06-25 sync. 미러는 엔진 실행 프로젝트(CyphenEngine.vcxproj)만 포함, DX11 백엔드 DLL은 별도 프로젝트(미러 밖).

# #2_7 플랜 (Linux 빌드 준비) + 브랜치 귀속 분석

## 1. #2_6 마감 확인 (미러 + devlog)

엔진 측 #2_6은 Q028 아키텍처 락대로 랜딩 완료, 커밋됨.
- Resource 레이어 / Content 코덱(Codec→ImageCodec→JpegCodec→WindowsJpegCodec WIC)
- 도메인 분리 IR: RenderCommand(Clear/Present/DrawTexturedQuad) ↔ ResourceCommand(Upload/Destroy), 둘 다 `CommandBuffer<T>` template
- byteCount 제거 header `Texture2DUploadPayload{format,width,height}` 12B
- Frame = ResourceId만
- ★ ABI 반전 실현: ABI 세대 4 유지, Debug 전용 `executeDebugResourceCommandList`만 `#ifdef _DEBUG` 추가(릴리즈 32B/디버그 40B)
- 부트스트랩: Profile/Profile2 `nextResourceId++` → ReadAllBytes → Codec::Decode → upload 1회 → 1초 단위 교체 draw

검증(devlog 26.06.24.txt): CoreIoTests 69/0, ModuleTests 34/0, Debug x64 Profile 1초 교체 확인, Present pacing 측정.

## 2. P1 경계 감사 결과 (미러 read-only)

**이미 Linux-ready (설계 선반영):**
- `Build/Public/framework.h` — 이미 `#if PLATFORM_WINDOWS / #elif PLATFORM_LINUX` 분기. Linux는 `<cstdint>`+`LARGEINTEGER=int64_t`. Windows.h는 PLATFORM_WINDOWS에서만.
- `Build/Public/PlatformDefine.h` — 빌드 주입 `TARGET_PLATFORM_*` → `PLATFORM_*` 매핑 완비. Linux 빌드는 `TARGET_PLATFORM_LINUX` 주입만 하면 됨.

**남은 실제 누수 (P1에서 봉합):**
- `pch.h` `_DEBUG` 블록 `crtdbg.h`/`_CRTDBG_MAP_ALLOC`/`#define new` — MSVC 전용, 플랫폼 가드 없음 → `#if PLATFORM_WINDOWS` 가드.
- `OutputDebugStringA` 4곳(Renderer.cpp, Engine/CyphenEngine.cpp, CoreIOTests, ModuleTest) — Win 전용 → 가드 또는 공용 디버그 출력 경로.
- `WindowsJpegCodec.cpp` — 예상된 Windows leaf, Linux 타깃 소스에서 제외(#3).
- `RenderCommand.h` "d3d11" — 주석뿐, 실누수 아님.

결론: 추상화 골격은 이미 섬. P1 실작업 = 미가드 MSVC/Win 누수 소수 봉합.

## 3. 현 Platform/HAL 경계 상태

빌드시점 concrete 선택(인터페이스 없음) 패턴 기구축. HAL 계약 / Platform 구현:
- ModuleLoader: Win ✅ / Linux ❌(dlopen)
- PlatformFile: Win ✅ / Linux ❌(POSIX fd)
- PlatformTime: Win ✅ / Linux ❌(clock_gettime)
- Launch: Win ✅(WinMain) / Linux ⚠️(빈 스텁 `#include "pch.h"`만)

## 4. #2_7 플랜 (P1~P2: 빌드 시스템까지) — 사용자 확정 범위

목표: 공통 코어가 Linux 빌드 시스템에서 **컴파일 통과**하는 지점까지. Platform 구현체/표시는 #3.

**P1. 공통 계층 Win 누수 봉합**
- pch.h `_DEBUG` 블록 `#if PLATFORM_WINDOWS` 가드
- OutputDebugStringA 4곳 가드 또는 공용 디버그 출력 경로 일원화
- 합격: 공통 .h/.cpp에 PLATFORM_WINDOWS 가드 밖 Win API 참조 0 (Windows leaf 제외)

**P2. Linux 빌드 시스템 도입**
- CMake 도입(cross-platform 표준, 추후 EGL/Vulkan 탐색 용이). MSVC vcxproj 병존.
- `TARGET_PLATFORM_LINUX` 주입, 공통 코어 + Platform/Linux(스텁) + Test 타깃 정의
- Windows-only(DX11 백엔드, WindowsJpegCodec) 타깃 소스 분리(빌드 조건)
- LF/탭/UTF-8 규칙 준수
- 합격: Linux `cmake` 구성 성공 + 공통 코어 컴파일 단계 진입. 미구현 Platform 심볼은 **링크 단계 노출 = #3 입력**.

### 미해결(차단 아님)
- 디버그 출력 일원화를 #2_7에서 sink로 뺄지 vs 단순 가드만 — sink 본격화는 Logger 단계(Todos 4) 권장. P1은 가드 최소.

## 5. 브랜치 귀속 분석 — #2 마감 vs #3 이동

두 기준이 다른 깊이를 가리킴:
- **devlog(#2 목표)**: "같은 구조가 다른 플랫폼에서도 빌드될 수 있는지 **확인**" → 동사는 "확인"(can build), "구현" 아님.
- **로드맵**: B3 = Linux build + integration test → 실제 Linux 빌드 성사 + 통합 테스트는 #3 몫.

충돌이 아니라 깊이 경계. #2는 *portability 증명*, #3는 *Linux를 실제로 세움*.

**추천(=확정): 경계선을 "컴파일된다"에 그음**
- #2_7 = P1~P2(누수 봉합 + CMake + 공통 코어 컴파일 통과) → **#2 마감**. 링크 미해결 심볼 = #3 시작점.
- #3 = Platform/Linux 구현(dlopen/POSIX/clock_gettime/main) + Windows-leaf 격리 + EGL/Linux JPEG first-light + 통합 테스트.

근거:
- #2 정체성 정합: #2 = Renderer 모듈 + 빌드시점 concrete 선택 브랜치. 그 아키텍처의 증명 = "두 번째 TARGET_PLATFORM에서 공통 코어가 컴파일된다". framework.h/PlatformDefine.h 분기가 이미 있으니 P1~P2는 설계의 회수이지 새 기능 아님.
- #3 정체성 정합: dlopen·POSIX·EGL·통합테스트는 분량·성격상 한 브랜치(#3). 로드맵 B3와 일치.
- 동사 일치: devlog는 #2에 "확인"만 요구.

반대안(#2에서 끝까지) 기각: P3~까지 #2에 넣으면 #2가 "Linux 포팅 브랜치"로 비대해지고 B3와 책임 중첩. 통합 테스트는 #2(Renderer)의 어휘 아님.
