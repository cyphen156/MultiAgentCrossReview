Date: 2026-06-25
Question-ID: Q001
Author: Claude(통합) + User 확정
Responds-To: Claud/Q001_001_plan_and_boundary.md + Callbacks/Q001_C001_user.md
Status: Decision
Baseline: 2026-06-25 sync (#2_6 마감 후)

# Decision Q001 — #2_7 범위 + 브랜치 경계 락

## 확정 사항

1. **#2_7 = Linux 빌드 준비, 범위 P1~P2, #2 마감 단계.**
   - P1: 공통 계층 Win 누수 봉합 (pch.h `_DEBUG` 블록 PLATFORM_WINDOWS 가드, OutputDebugStringA 4곳 가드/일원화).
   - P2: CMake 도입 + `TARGET_PLATFORM_LINUX` 주입 + 공통 코어/Test 타깃 정의 + Windows-only leaf(DX11 백엔드·WindowsJpegCodec) 빌드 분리. MSVC vcxproj 병존.
   - 합격: Linux `cmake` 구성 성공 + 공통 코어 컴파일 통과. **미구현 Platform 심볼은 링크 단계 노출 = #3 입력.**

2. **브랜치 경계 = "컴파일된다".**
   - #2(Renderer 모듈 + 빌드시점 concrete 선택)는 portability를 **증명**하고 마감. devlog #2 목표 동사 "확인"과 일치.
   - 실제 Linux 빌드 성사·표시·통합 테스트는 #3(=로드맵 B3).

3. **#3 범위(이월):** Platform/Linux 구현 3종(ModuleLoader=dlopen, PlatformFile=POSIX fd, PlatformTime=clock_gettime) + Launch `main()`, Windows-leaf 격리 마무리, OpenGL ES/EGL Renderer 백엔드 + Linux JPEG leaf(libjpeg-turbo/stb) first-light, 통합 테스트. Vulkan 이후.

## 범위 제외 (devlog 명시)
- ResourceManager / FrameQueue / Mesh·Material → Linux 빌드 확인 이후.
- Vulkan → 이후 단계.

## 미해결 (차단 아님, 구현 시점)
- 디버그 출력: P1은 가드 최소, sink 본격화는 Logger 단계(Todos 4).
- WindowsJpegCodec 위치(Content vs Platform/Windows): #3 Linux JPEG leaf 도입 시 자연 분기 → #3에서 결정.

## 비고
- 오늘 Codex 부재 → 본 Decision은 Claude 단독 기획 + 사용자 확정. 교차검증 단계 없음.
- 최종 코드 수정·커밋·푸시는 사용자.
