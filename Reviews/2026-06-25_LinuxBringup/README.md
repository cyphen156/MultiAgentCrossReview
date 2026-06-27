# Linux Bringup (#3 / 로드맵 B3) 검토 요약

> 이 파일만 **가변**(현재 상태 요약). 독립 판단·교차검증·수정 결론·증거 확인은 append-only.

- **질문**: #3 브랜치 시작 — Linux 실구현 + 통합 테스트 전체 플랜. (Questions/Q001.md)
- **범위**: A 실구현 3종(PlatformTime/PlatformFile/ModuleLoader) + B Launch/main(링크 게이트) + C Windows-leaf 격리 마무리 + D Renderer first-light(GLES/EGL + Linux JPEG leaf) + E 통합 테스트.
- **제외**: ResourceManager/FrameQueue/Mesh·Material, Vulkan (이월).
- **Baseline**: 2026-06-25 sync (8ed15ad / #2 마감 직후)

## 현재 결론 (갱신됨)

전체 플랜 Plan-Draft 작성(Q001_001). 권장 순서 = **A1 PlatformTime → A2 PlatformFile → A3 ModuleLoader → B Launch/main(★링크 게이트) → C 병행 → D first-light → E 통합테스트**.
링크 게이트가 #2가 남긴 경계의 공식 해소점. 착수 직전 결정 필요 = **Linux 빌드 환경(§4-1)**.
Linux 4종은 빈 플레이스홀더로 확인 → A는 실구현(Windows 동명 구현이 레퍼런스).

**렌더러 백엔드 라인 확정(Q001_002):** 메인 = Dx11, 크로스플랫폼/Linux = **Vulkan**, GLES = 보류(스켈레톤 유지·미투자), Metal = 포기.
**#3_1** = Platform 미러 + `CyphenRendererVulkan` **스캐폴드까지**(빌드·로드 OK, 안 그림). **#3_2** = Vulkan first-light, **Windows에서 먼저**.
이식 항목: `__declspec(dllexport)`(모듈 export) Linux 미적용 → visibility-default 매크로 필요(ModuleLoader/dlopen과 묶음).

**미러 감사(Q001_003):** Platform/Linux 파일셋 누락 0(LinuxString 포함 완비). 단 두 가지 — ① **LinuxString = 슬롯 유지·내용 빈 상태(C001 확정)**: UTF-8 기본에선 무참조, UTF-16 전환 시 `ToNarrowString` 채움. ② **Vulkan vcxproj가 콘솔앱 템플릿**(Application/Win32/props·include·define 누락) → Dx11 미러로 교정.

**Vulkan 스캐폴드 BUILD PASS(Q001_004):** 교정본을 원본에 1회-허용 적용 + 빌드. `.vcxproj.user`가 옛 vcxproj 복사본(134줄)이라 소스 이중 컴파일 → Dx11식 최소 .user로 교정. Rebuild EXITCODE=0·경고 0, `CyphenRendererVulkan.dll` 생성, `GetRendererModuleApi` export 확인. #3_1 렌더러 스캐폴드 절반 완료. 남은 #3_1 = Platform 미러 A.

**#3_1 마감 산출물:** 커밋 메시지 `Claud/artifacts/commit_3_1.txt`, 데브로그 `Claud/artifacts/26.06.25_2.txt`(원본 `CyphenEngine/DevLog/2026/26.06.25_2.txt`에 배치). 커밋 전 Vulkan 모듈테스트용 `Windows/Launch.cpp`(Dx11→Vulkan 디스크립터)는 제외. **다음 = #3_2: Platform/Linux 구현 본체(A1 PlatformTime → PlatformFile → ModuleLoader → Launch), WSL2+gcc.**

## 기록 인덱스

| # | 파일 | Author | Responds-To | Status |
|---|---|---|---|---|
| 001 | Questions/Q001.md | User | none | Open |
| 002 | Claud/Q001_001_b3_plan.md | Claude | Q001 + LinuxBuildPrep Decision §3 | Plan-Draft |
| 003 | Claud/Q001_002_renderer_backend_lock.md | Claude(권고)+User | Q001_001 + 사용자 결정(Vulkan) | Decision-Followup |
| 004 | Claud/Q001_003_mirror_audit.md | Claude | 사용자 미러 확인 요청 | Evidence-Check + Impl-Draft |
| 005 | Callbacks/Q001_C001_user.md | User | Q001_003 §B·§C/D | Callback |
| 006 | Claud/Q001_004_vulkan_scaffold_build_pass.md | Claude | Q001_003 + 1회 적용 허용 | Evidence-Check (BUILD PASS) |

사용자 개입이 있으면 `Callbacks/Q001_CNNN_user.md`로 함께 기록한다.

## 최종 판정

(미정 — Decision/Q001_decision.md 예정)
