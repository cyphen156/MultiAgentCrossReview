Date: 2026-06-22
Question-ID: Q001
Author: User (final judgment)
Responds-To: Codex/Q001_001, Codex/Q001_002, Claud/Q001_003
Status: Decision-Final
Baseline: 2026-06-22 workspace mirror

# 사용자 최종 판정 — Renderer Module 계약

## 확정 아키텍처
- Renderer Core는 **엔진측 공통 시스템**. DX11은 **선택 구현 DLL**. Core를 각 DLL에 복제하는 안(🟡)은 미채택, 대안으로만 보관.
- 로직(패스·순서·기능 정책·Command List 생성)=Renderer / 번역·실행(DX11 객체·Draw)=구현체.
- Engine↔DLL 경계는 **Command List 배치 단위**. 기능은 함수표가 아니라 `RenderCommandType`/데이터로 확장.
- 추상화는 `IModule` 상속이 아니라 **`ModuleBinding` 비가상 합성**. Engine이 Core 시스템 초기화 순서를 명시 호출. (외부 미지 모듈 공통 디스패치는 플러그인 단계로 이월.)
- ModuleManager는 **도메인 무지** 바이너리 Runtime Manager. Refresh(desired 상태)와 실제 Load는 분리. Load/Unload는 멱등.
- 수명: **`Acquire/Release` 참조 수명**. 첫 Acquire에서 Load, 마지막 Release에서 Unload. refcount는 ModuleManager가 관리. ModuleBinding은 자신이 획득한 것만 Release → "실패 롤백이 남의 DLL을 내리는" 문제 제거.

## #2_3 범위 (지금 마감)
- DLL 계약 = `GetRendererModuleApi() → {apiVersion, rendererType}` 하나.
- 흐름: Launch가 Descriptor 주입 → `ModuleManager::Refresh` → Engine 순서로 `Renderer::Initialize`(ModuleBinding::Acquire → Load → GetRendererModuleApi → apiVersion/rendererType 검증 → API 캐싱) → 실패 시 API 해제 + Release → `Renderer::Shutdown`(API 해제 + Release) → Engine 종료 후 `ModuleManager::Shutdown` 안전망.
- 버전: Debug=개발버전(2), Release=정식(1). ABI 구조 변경 시 개발버전 증가. 0.xx/float 미사용.

## #2_4 이후 (이월)
Render Thread · Frame/Command Queue · `RenderCommandList`/`FramePacket` · `Execute`/`CreateRenderer`/`DestroyRenderer` 실행 ABI · `RendererCapabilities`(Device 의존, 재생성 시 갱신) · Device/SwapChain · 백엔드 GPU 수명 · PipelineDescriptor · 범용 Resource Handle(GDDR 상주·streaming 시점) · 동기화/back-pressure 정책.

## 비용 합의
얻음: 런타임 백엔드 교체, Renderer 로직 단일화, 플랫폼 의존성 격리, 작은 DLL 함수표, 배치 단위 경계, 테스트 경계 명확.
지불: Command IR(ABI) 설계, 배치 해석·메모리 비용, Thread/Queue 동기화, DLL ABI·디버깅 복잡도, 정적 링크 최적화 일부 포기. — 엔진 토대로서 합리적 거래로 합의.

## 보정 반영 (Claud/Q001_003 교차검증)
- 미래 실행 계약(Execute/Capability/GPU 수명)은 #2_4 — #2_3 사실로 쓰지 않음.
- 비용 비교 기준은 "명령 소비 이후"(fine-grained N회 / batched 1회+내부 직접 / static 직접). 독립 Render Thread에선 Command 해석이 어차피 필요.
- Resource Handle: 범용 체계는 이월, Device/SwapChain은 DLL 내부 상태로만.

## 종료
#2_3 설계 선택 항목 없음. 구현·검증만 남음. 네이밍: ModuleBinding은 `Acquire/Release`로 통일.
