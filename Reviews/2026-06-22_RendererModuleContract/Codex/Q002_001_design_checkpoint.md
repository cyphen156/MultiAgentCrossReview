Date: 2026-06-23
Question-ID: Q002
Author: Codex
Responds-To: User discussion and Claude cross-review
Supersedes: none
Status: Design-Checkpoint
Baseline: 2026-06-22T23:29 sync

# #2_5 Renderer Frame 전달과 RHI Word Stream 설계 체크포인트

## 확정한 책임 경계

- Runtime/World는 월드 상태를 확정하고 한 프레임의 불변 `RenderFrame` Snapshot을 생성한다.
- `BeginRenderingFrame(RenderFrame&&)`은 Snapshot의 소유권을 Renderer Queue로 이전하는 UE식 비동기 진입점이다.
- Render Thread는 Snapshot을 읽기 전용으로 소비하며 렌더링 파이프라인을 결정한다.
- Render Thread가 x64 기준 64비트 RHI Word Stream을 생성한다.
- Renderer 구현 DLL은 `ExecuteRhiCommandList`로 Stream을 받아 DX11/Vulkan 명령으로 번역·실행한다.
- `CyphenEngine`은 Runtime/Scene이 생기기 전까지만 최소 `RenderFrame`을 생산하는 임시 bootstrap 주체다. RHI Command를 직접 만들지 않는다.

## Frame 전달 계약

- Engine/Game 측의 가변 World 객체 포인터를 Render Thread에 직접 전달하지 않는다.
- Submit 이후 생산자는 Snapshot을 수정하거나 재사용하지 않는다.
- Queue가 Snapshot 소유권을 보관하고 Render Thread가 소비 완료 후 슬롯을 반환한다.
- 초기 Queue depth는 pending 1개다. Render Thread가 N을 실행하는 동안 N+1 한 프레임만 대기할 수 있다.
- 실제 Snapshot pooling/arena는 메시·Transform 등 비단순 데이터가 들어오는 시점까지 이월한다.

## RHI Word Stream 계약

- `RhiCommandHeader`는 `RhiCommandType:uint32 + payloadWordCount:uint32`로 정확히 8바이트다.
- `RhiCommandList` ABI View는 `{words, wordCount, commandCount}`로 16바이트다.
- Builder와 Parser는 `memcpy`를 사용하고 Header/Payload typed pointer cast에 의존하지 않는다.
- Parser는 Word 경계, Payload 크기, Command 개수, 최종 cursor를 검증한다.
- 알 수 없는 Command Type은 현재 ABI 세대에서는 Failure다.
- #2_5 Command는 `ClearRenderTarget`과 `Present`만 추가한다.
- `RendererModuleApi`에 `ExecuteRhiCommandList`를 추가하고 ABI Generation을 3에서 4로 증가시킨다.

## 동기화 불변식

- condition_variable predicate 상태는 대응 mutex 안에서만 변경한다.
- 공유 스타일 규칙에 따라 predicate lambda를 사용하지 않고 명시적 `while` 대기를 사용한다.
- 종료 시 Frame Queue를 먼저 Stop하여 생산자·소비자 대기를 깨운 뒤 Render Thread를 Join한다.
- Render Thread가 끝난 뒤 Renderer Handle, API 함수 포인터, Module Binding 순으로 해제한다.

## 다음 구현 순서

1. `RenderFrame` / `RenderFrameQueue` 추가.
2. `RhiCommand` / `RhiCommandBuffer` 추가.
3. Renderer에 `BeginRenderingFrame`, `ProcessFrame`, `BuildRhiCommandList` 연결.
4. DX11 Back Buffer RTV 생성과 RHI Parser 구현.
5. `ClearRenderTargetView` + `Present(1, 0)` 가시 출력 확인.
6. Debug x64 Build, CoreIoTests, 실행·종료·DLL unload 및 DXGI 경고 확인.

## 이월

- 실제 Scene/View Snapshot 데이터.
- Snapshot buffer pool 또는 frame arena.
- Resize/WM_SIZE, VSync 설정 변경, Capability.
- SetPipeline/Draw/Dispatch와 GPU Resource Handle.
- Runtime/Scene/Viewport로 Frame 생산 책임 이전.
