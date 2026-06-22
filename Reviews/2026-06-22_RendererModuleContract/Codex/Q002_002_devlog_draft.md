Date: 2026-06-23
Question-ID: Q002
Author: Codex
Responds-To: Q002_001_design_checkpoint.md
Supersedes: none
Status: DevLog-Draft
Baseline: 2026-06-22T23:29 sync

# DevLog/2026/26.06.23.txt 초안

```text
Date: 2026-06-23
Branch: #2-Renderer-모듈-개발

작업 요약
	Renderer Module의 Binding 수명 계약과
	Render Thread 기반 DX11 실행 인스턴스 수명을 마감했습니다.

	#2_5 진입을 위해 Runtime의 불변 RenderFrame Snapshot을
	Renderer Thread에 전달하는 프레임 생산·소비 경계를 정리했습니다.

	Renderer가 Snapshot을 독립적으로 소비하여 렌더링 파이프라인을 결정하고,
	64비트 RHI Word Stream을 생성해 구현 DLL에 제출하는 방향을 확정했습니다.


진행한 커밋
	#2_3 [Renderer] Renderer Module 바인딩 수명 계약 완성
	#2_4 [Renderer] Render Thread와 DX11 실행 인스턴스 수명 구현


주요 정리 내용
	1. Renderer Module Binding 수명 마감
		ModuleDescriptor의 논리 Module, 선택 구현,
		Native Binary 이름을 분리했습니다.

		ModuleBinding과 ModuleManager의 Acquire / Release를 통해
		Renderer가 자신의 구현 참조만 획득하고 해제하도록 구성했습니다.

		RendererModuleApi의 ABI Version과 RendererType을 검증하고,
		검증 실패 시 획득한 Binding을 롤백하도록 정리했습니다.

	2. 공통 Thread primitive 추가
		std::thread 생성 실패를 bool 결과로 변환하고,
		Join 실패는 Thread 내부의 복구 불가능한 수명 오류로 처리했습니다.

		Engine Thread와 Render Thread가 같은 Thread 계약을 사용하도록 구성했습니다.

	3. Renderer 객체와 Render Thread 수명 구현
		Renderer를 CyphenEngine이 소유하는 객체로 변경했습니다.

		Renderer가 Module Binding, RendererModuleApi,
		Render Thread 상태를 단일하게 소유하도록 구성했습니다.

		Renderer 구현 인스턴스의 생성과 파괴를
		Render Thread에서 수행하도록 연결했습니다.

	4. DX11 실행 인스턴스 구현
		Dx11Renderer에 D3D11 Device, ImmediateContext,
		Flip Discard SwapChain 생성과 파괴를 구현했습니다.

		Debug Layer를 우선 요청하고 SDK Component가 없는 환경에서는
		Debug Layer 없이 다시 생성하도록 처리했습니다.

	5. #2_5 프레임 전달 책임 확정
		Runtime / World는 월드 상태를 확정하고
		한 프레임의 불변 RenderFrame Snapshot을 생성합니다.

		BeginRenderingFrame은 Snapshot 소유권을 Renderer Queue로 이전하고,
		Render Thread는 Snapshot을 읽기 전용으로 소비합니다.

		Runtime / Scene이 생기기 전까지 CyphenEngine은
		최소 RenderFrame을 생산하는 임시 Bootstrap 주체로 둡니다.

	6. RHI Word Stream 형식 확정
		Renderer와 구현 DLL 사이의 실행 계약은
		x64 기준 64비트 RHI Word Stream을 사용합니다.

		Command Header는 Type과 Payload Word Count를 담는 8바이트 구조이며,
		RhiCommandList는 Pointer / Word Count / Command Count를 전달합니다.

		Renderer가 RHI Command를 생성하고,
		DX11 구현체가 Stream을 해석하여 실제 API 호출로 실행합니다.

		#2_5의 첫 Command는 ClearRenderTarget과 Present로 제한합니다.


정리된 설계 기준
	- Engine / Runtime은 월드 상태와 RenderFrame Snapshot을 생산합니다.
	- Renderer는 Snapshot을 소비해 렌더링 파이프라인을 결정합니다.
	- Renderer Thread는 RHI Word Stream을 생성합니다.
	- 구현 DLL은 RHI Word Stream을 플랫폼 그래픽스 API로 번역·실행합니다.
	- Snapshot Submit 이후 생산자는 소비 완료 전까지 데이터를 수정하지 않습니다.
	- Frame Queue와 RHI Command Stream은 서로 다른 책임으로 분리합니다.
	- condition_variable predicate는 대응 mutex 안에서만 변경합니다.
	- 공유 스타일 규칙에 따라 predicate lambda를 사용하지 않습니다.


검증
	CoreIoTests PASS=69 / FAIL=0

	Debug x64에서 CyphenRendererDx11.dll과
	D3D11 Device / ImmediateContext / SwapChain 생성을 확인했습니다.

	Render Thread와 Engine Thread가 정상 종료되고,
	CyphenEngine.exe가 코드 0으로 종료되는 것을 확인했습니다.


다음 작업
	#2_5 [Renderer] RenderFrame 전달과 RHI Command 실행 경로 구현

	RenderFrame / RenderFrameQueue와
	RhiCommand / RhiCommandBuffer를 추가합니다.

	Renderer의 BeginRenderingFrame에서 Snapshot을 제출하고,
	Render Thread가 ClearRenderTarget / Present Word Stream을 생성하도록 연결합니다.

	Dx11Renderer에 Back Buffer RenderTargetView와 RHI Parser를 추가하고,
	창이 지정된 단색으로 출력되는 것을 검증합니다.
```
