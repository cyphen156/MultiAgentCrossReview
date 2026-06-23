Date: 2026-06-23
Question-ID: Q001
Author: Claude
Responds-To: Claud/Q001_008_evidence_check.md + #2_5 다회차 개정·커밋
Supersedes: none (008을 보강·갱신)
Status: Implemented (#2_5 commit) / 일부 #2_6 이월
Baseline: 2026-06-23T15:51 sync

# Q001 #2_5 개정 결론 + 커밋 후 검증 (Claude)

008(수렴) 이후 #2_5는 여러 라운드로 크게 개정되었고 커밋으로 닫혔다. 최종 결정과 검증을 기록한다.

## 1. 책임 계층 (확정)
Engine/Runtime(월드 상태 결정·스냅샷) → Renderer(스냅샷 소비, render thread에서 RenderCommand IR 생성)
→ executeCommandList(ABI 경계) → Dx11Renderer(RHI 명령을 D3D11 호출로 번역).
- 공개 API는 "제출"(BeginRenderingFrame), 조합기는 내부 BuildRenderCommandList(render thread).
- 스냅샷 불변성: 생산자는 제출 후 의존 금지(POD 복사 핸드오프).

## 2. Naming 확정 (진동 이력 포함 — 재오픈 방지)
- 입력 타입: RenderFrame → FrameInfo → RenderSnapshot(철회) → **Frame** (공개 POD, Modules/Renderer/Public).
  "snapshot"은 타입명이 아니라 사용 맥락(지역변수)의 의미로 둔다.
- 명령 IR: RenderCommand → Rhi → RenderCommand (5회 진동).
  최종 절단 기준 = **기존 Render* 코드베이스 컨벤션** + 도메인 명명(Render/Audio/Network + Command).
  RHI는 (a) 오디오/네트워크 HW에도 쓰는 일반어, (b) 코드베이스에 Rhi* 고아 stem 없음 → RenderCommand.
- 진동 원인 = 매번 다른 기준(충돌회피/위치/수준/도메인). 재오픈 금지: 이름은 가역적 cosmetic.

## 3. 공통 Command Stream 추출 (확정)
- 메커니즘(carrier) vs 정책(semantics) 분리: Modules/Public/ModuleCommand(.h) + ModuleCommandBuffer.
  RenderCommand/RenderCommandBuffer는 그 위 도메인 계층.
- 핵심 원칙: YAGNI/wrong-abstraction 경계는 **행위/상속 투기**에 거는 것이지 **무가정 POD 메커니즘**에 거는 게 아니다.
  미추출 시 미묘한 직렬화(padding/memcpy/경계검사) 중복 → 버그원. 실사용자 1이어도 메커니즘은 추출이 맞다.
- 가드레일: carrier에 도메인 가정/투기 필드(timestamp/priority 등) 금지. tagged POD + enum 태그 + switch, 상속/virtual 금지.

## 4. 배치 / 계층 (확정)
- Core에서 Module 계열 제거 → Modules/Public|Private (ModuleDescriptor/ModuleManager/ModuleBinder).
  UE는 FModuleManager를 Core에 두지만, leaner-Core 의도의 분기.
- 규율: **Modules/Public(모듈 시스템)은 Core+HAL만 의존** (Engine/Renderer 의존 금지). 디렉터리(Modules)≠계층(top).
- ModuleLoader는 HAL/Platform 유지(native binary load).
- ModuleBinding → ModuleBinder. helper RollbackInitialization → ReleaseModuleBinding (Initialize 실패 + Shutdown 공용).

## 5. 커밋 후 블로커 검증 (Baseline 2026-06-23T15:51)
이전 리뷰의 차단 3건이 코드로 해소됨을 확인:
- 이름 해소: ModuleDescriptor{moduleName, implementationName, binaryName}, Acquire가 논리명→binaryName 해소.
  Launch가 moduleName="Renderer"/impl="Dx11"/binary="CyphenRendererDx11" 부트스트랩. (ModuleManager.cpp / Launch.cpp)
- Acquire/Release = refcount, 마지막 참조에서만 Unload. Refresh는 desired만 선언, 적재는 lazy.
- 파서 오버플로: Dx11Renderer::ExecuteCommandList가 `payloadWordCount > wordCount - cursor` 뺄셈형으로 수정.
- 검증: ModuleTests PASS=34 / FAIL=0, Debug x64에서 Clear/Present 실행 경로 확인(커밋 메시지).

## 6. #2_6 이월 (의도된 미해결)
- ProcessFrame이 executeCommandList 결과를 (void)로 삼킴 → 실패 전파 없음. #2_6 "실패 정책"에서 복원.
- Resize/WM_SIZE/SwapChain 재생성 부재 → #2_7.
- device-lost(DEVICE_REMOVED) 처리, Backend Capability(예: selectedFeatureLevel은 현재 (void) 폐기) → #2_6.
- 제안 순서: #2_6 Capability/Surface/실패계약 → #2_7 Resize → #2_8 Pipeline/Draw 최소.

## 결론
#2_5는 "Renderer가 Frame을 받아 RenderCommand IR로 컴파일하고 Backend가 실행"을 닫은 커밋.
차단 없음(3건 커밋에서 해소 확인). 실패정책·Resize·Capability는 #2_6 이후로 정당하게 이월.
실제 코드 적용·커밋은 사용자가 수행함(미러 읽기 전용).
