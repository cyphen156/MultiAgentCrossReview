Date: 2026-06-22
Question-ID: Q001
Author: Claude
Responds-To: Codex/Q001_001_contract_revision.md, Codex/Q001_002_naming_revision.md
Supersedes: none
Status: Cross-Review-Complete
Baseline: 2026-06-22 workspace mirror (Source DevLog #1_17까지 동기화)

# 교차검증 결론

설계 본체(Renderer=엔진측 공통 시스템 / DLL=선택 구현 / 레시피=Renderer·조리=구현체 / 굵은 경계)는 맞다.
다만 직전 24항 요약은 **미래 실행 계약과 미구현 ModuleManager 목표 상태를 현재 사실처럼 서술**한 부분이 있어 그대로 기록하면 안 된다.
아래는 Codex 교차검증(13건)을 수용해 *현재 기준선 / 목표 계약 / 이월*을 분리한 최종본이다.

# 1. 개념 핀 (불변식)

1. **Module ≠ DLL.** Module은 독립된 기능·수명·구성 경계를 가진 논리 패키지다. Renderer Module은 *그중 복수 구현을 선택하는* 형태다(모든 Module이 복수 구현을 갖는 건 아니다). DLL은 선택 구현의 아티팩트다.
2. **Load ≠ Use.** DLL 적재(LoadLibrary, 모듈 불가지)와 활성화(바인딩·실행, 도메인 특정)는 별개 단계다.
3. **Renderer(엔진측 시스템) ≠ DLL(백엔드 구현).** Renderer는 엔진 내부 공통 렌더링 시스템이고, `CyphenRendererDx11.dll`은 그 선택 구현 바이너리다. 렌더러가 DLL을 쓰는 쪽이다.
4. **로직(균일)=Renderer / 번역(백엔드)=구현체.** "무엇을 어떤 순서로 그릴지(레시피)"는 Renderer, "DX11로 어떻게 쏠지(조리)"는 구현체.

# 2. 계층과 책임

| 계층 | 책임 |
|---|---|
| Engine | 시스템 시작·종료 순서, 게임 상태와 프레임 진행 |
| Renderer | 공통 렌더링 파이프라인(레시피), Render Thread, Command Queue, 기능 정책 |
| RendererModuleApi | Renderer와 선택 구현 사이의 ABI 계약 (발견·버전·수명·실행). #2_3은 발견·식별만 구현 |
| Dx11Renderer | Command List를 DX11 호출로 번역·실행 |
| ModuleManager | Descriptor 관리, 구현 DLL 적재·수명 관리 |

# 3. 파이프라인 책임 분리 (수정 #8)

- **Renderer**: 백엔드 중립 `PipelineDescriptor` 구성 + 어떤 Pipeline을 쓸지 결정. 패스 시퀀스(Shadow/Depth/Geometry/Lighting/Post/UI/Present) 소유.
- **구현체**: `PipelineDescriptor`를 `ID3D11*` 객체로 생성·캐싱·바인딩, draw 실행.
- 즉 **PSO의 논리적 정의 = Renderer, 네이티브 객체 = 구현체.**
- `RenderLightmap()`/`RenderObstacle()` 같은 고수준 기능은 DLL에 넣지 않는다(= Renderer 정책).
- 명령은 RHI 수준 그리기 동작(BeginPass/SetPipeline/BindResource/DrawIndexed/Dispatch/EndPass/Present)이며 게임 개념도 GPU 비트도 아니다.

# 4. 실행 모델 (🟢 확정 — 수정 #24)

```
Game Thread   → Renderer::SubmitFrame(frame)  → frameQueue.Push   (직접 호출)
Renderer Thread→ 공통 파이프라인 실행 → RenderCommandList 생성 → api.Execute(list)  (배치당 ABI 1회)
DX11 DLL      → Command List 해석 → 내부 직접 호출 → ID3D11DeviceContext (COM)
```

- 공개 `Renderer::SubmitFrame`은 큐 push만, 내부 Thread 함수가 루프를 소유한다. Thread/Queue/활성 API 상태는 한 곳(시스템 객체)이 소유하고 네임스페이스 facade는 forward만 한다.
- **Renderer Core는 엔진측에 둔다. DLL은 Command List 번역·실행을 담당한다.** DLL 내부 Core 복제안(🟡)은 채택하지 않고 *대안으로만 보관*한다. (🟢/🟡 성능을 "동률"이라 단정하지 않는다 — 배치 수·데이터 크기·IR 해석 비용이 다르다.)

# 5. 실행 계약 (수정 #6 · #23)

- 실행 계약은 `Execute(CommandList)`라는 **굵은 진입점 중심**으로 설계하고, 렌더 기능마다 함수표를 늘리지 않는다(기능 증가 = `RenderCommandType`/데이터 증가).
- **정확한 함수표는 #2_4에서 확정**한다. Capability 반환·실행 인스턴스 핸들·Device 복구 계약이 추가될 가능성이 있다.
- `RendererModuleApi`는 발견·버전·수명·실행 ABI 계약이다. **현재 #2_3에서는 발견·식별 부분만 구현**한다(현재 `RendererModule.h` = `{apiVersion, rendererType}`).
- 두 Initialize/Shutdown 층을 이름으로 구분한다: `IModule::Initialize/Shutdown`(엔진측 시스템 수명, #2_3) ≠ DLL 측 백엔드 GPU 수명(#2_4, 이름 분리 권장).

# 6. 기능 지원 판단 (수정 #9)

검사 축을 구분한다: ABI Version(구조체·함수표 호환) / RHI Capability(구현이 표현 가능한가) / Hardware Capability(GPU·드라이버 실제 지원) / UserPreference / Runtime State(Device 정상 여부).
Capability는 **선택 구현과 Device가 생성될 때 조회·캐싱하고, Device/Adapter 재생성 시 다시 갱신**한다. #2_4 이전에는 Device가 없으므로 **capability 계약도 이월**이다. Renderer가 caps∩pref로 렌더 경로를 선택한다.

# 7. 비용 모델 (수정 #11 · #13 · #14)

- **경계 간접 호출 수 = 제출 배치 개수** (RHI 명령 개수 아님). `1 batch/frame`은 초기 목표일 뿐 불변식이 아니다(한 프레임에 여러 Command List 가능).
- DLL 내부 자체 래퍼·구체 구현 호출은 직접 호출·인라인 대상이 될 수 있다. **다만 런타임 Command 해석은 분기, DX11 COM 호출은 간접 호출이 남는다.**
- hot path CPU 비용은 Queue 하나가 아니라 함께 존재한다: 스레드 간 Queue 동기화 / Frame·Command 복사 및 캐시 이동 / Command IR 순회·분기 / Driver 제출 / CPU·GPU fence와 back-pressure.
- 간접 호출 비용과 동기화 비용은 **다른 축**이다(이 결론은 유효).
- `IModule` 상속 시 vtable은 수명 경로(Initialize/Shutdown)에만, Run/Submit은 비가상·직접 호출.

# 8. 수명·적재 (수정 #17 · #18~19 · #20)

- **목표 계약**: 멱등 `Load/Unload` + `Refresh`(desired 상태)와 실제 적재 조정(LoadAll/Load)의 분리.
  **현재 기준선은 아직 이를 충족하지 않는다** — `ModuleManager.cpp:145` Load는 이미 로드 시 `false`를 반환(비멱등), `Refresh`(line 20)가 Descriptor 갱신과 Load/Unload를 함께 수행한다. 이는 #2_3/#2_4에서 맞춰야 할 목표이지 현재 사실이 아니다.
- **소유권**: Renderer가 실패·종료 시 무조건 `Unload`하면 다른 경로가 적재한 DLL까지 내릴 수 있다. → `ModuleBinding::Acquire/Release` 참조 수명 또는 ownership token으로, **Renderer는 자신이 획득한 binding만 Release하고, 실제 native unload 여부는 ModuleManager가 결정**한다.
- **추상화**: Core 시스템만 대상이면 `ModuleBinding`(비가상 합성 + Engine 명시 호출)이 현재 철학에 더 맞다. 단 이는 *외부 주입된 미지의 모듈 활성화는 지원하지 못하며* 그 경우 공통 활성화 계약(`IModule`류)이 필요해 **플러그인 단계로 이월**된다. (이 조건을 명시한다 — `IModule` 폐기로 단정하지 않는다.)
- ModuleDescriptor = `moduleName / implementationName / binaryName / isEnabled`. Launch 하드코딩은 Descriptor 파일·UserPreference Resolver가 없어 둔 임시 부트스트랩.
- ModuleManager 조회·심볼 탐색은 hot path에서 수행하지 않는다(활성화 시 API 캐시).

# 9. 작업 범위

## #2_3 — 지금 마감
Descriptor 등록 → 선택 구현 DLL Load → `RendererModuleApi` 조회·검증(`{apiVersion, rendererType}`) → (엔진측)시스템 Initialize·바인딩 → Shutdown → DLL Unload. 공통 수명 계약, API 버전 검사, 구현 선택·바인딩, 실패 롤백(자신이 획득한 binding만), 역순 종료.

## #2_4 — 다음
Render Thread, Command Queue, RenderFrame, RenderCommandList, `Execute` 실행 계약·정확한 함수표, RendererCapabilities(Device 의존), Device 복구, DX11 명령 해석, 백엔드 GPU 수명(Initialize/Shutdown 함수포인터).

# 10. 메타 교훈

- 기록은 **목표 계약 / 현재 기준선 / 이월**을 항상 분리한다. 미래 계약을 현재 사실로 쓰지 않는다.
- 멱등 Load 위에서는 단일 소비자라도 **참조 수명(Acquire/Release)** 으로 unload 책임을 분리해야 안전하다.
