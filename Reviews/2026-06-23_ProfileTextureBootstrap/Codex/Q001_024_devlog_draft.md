Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User request: DevLog draft after #2_5 and profile texture design discussion
Supersedes: none
Status: DevLog-Draft
Baseline: 2026-06-23T19:08 sync

# DevLog/2026/26.06.23.txt draft

```text
Date: 2026-06-23
Branch: #2-Renderer-모듈-개발

작업 요약
	#2_5 Renderer Command Stream 구현을 정리했습니다.

	Engine Thread가 생산한 Frame을 Render Thread로 전달하고,
	Render Thread가 ClearRenderTarget / Present command stream을 생성해
	DX11 Renderer DLL이 실행하는 경로를 구성했습니다.

	다음 단계에서 Profile.jpg / Profile2.jpg를 표시하기 위한
	Profile Texture Bootstrap 설계 초안도 함께 정리했습니다.

	Profile Texture Bootstrap은 아직 원본 코드에 적용하지 않았으며,
	이번 DevLog에서는 구현 항목이 아니라 다음 작업을 위한 설계 초안으로만 기록합니다.


진행한 커밋
	#2_5 [Renderer] RenderFrame 전달과 RHI Command 실행 경로 구현


주요 정리 내용
	1. #2_5 Renderer Command Stream 구현
		Renderer는 Frame을 받아 RenderCommandBuffer를 구성하고,
		RendererModuleApi::executeCommandList를 통해 Backend DLL에
		RenderCommandList를 전달합니다.

		RenderCommand IR은 64-bit word stream을 사용합니다.
		#2_5 명령 집합은 ClearRenderTarget과 Present로 한정했습니다.

		Render Thread는 Renderer 구현 인스턴스를 생성하고,
		Frame 수신, command buffer 작성, backend 실행, 종료 시
		destroyRenderer 호출까지 수행합니다.

	2. Profile Texture Bootstrap 설계 초안
		Profile texture 표시는 정식 Runtime ResourceManager 기능이 아니라
		Debug bootstrap fixture/demo로 설계했습니다.

		Release 빌드에서 자동 표시되는 런타임 기능은
		ResourceManager와 texture/mesh 해석 체계가 들어온 뒤 별도로 다룹니다.

		이 설계 초안은 아직 원본 코드에 적용하지 않았습니다.

	3. Content Codec 계층 위치 초안
		파일 포맷 해석 계층은 Core / Resource / Module이 아니라
		Source/Content 아래에 두는 방향으로 정리했습니다.

		Core는 CString, Path, File, FileSystem, TextCodec 같은
		기초 기능과 낮은 수준의 I/O 도구를 담당합니다.

		Content는 content file byte buffer를 엔진 중간 표현으로
		해석하는 계층으로 둡니다.

		ResourceManager는 이후 Content Codec 결과를 받아
		Runtime resource / cache / handle / lifetime을 관리합니다.

	4. TextCodec 유지 초안
		TextCodec은 기존 Core text 변환 도구로 유지합니다.

		TextCodec을 Codec으로 리네임하지 않습니다.
		File::ReadAllText / WriteAllText는 계속 TextCodec을 사용합니다.

		새로운 Codec은 TextCodec을 대체하는 클래스가 아니라,
		content file type을 보고 leaf codec으로 분배하는 facade로 둡니다.

	5. Codec dispatch 초안
		Codec은 확장자를 직접 if-chain으로 처리하지 않습니다.

		Path에서 확장자를 추출하고,
		정규화된 extension table로 CodecKind를 resolve한 뒤,
		switch-case로 leaf codec을 호출합니다.

		JPG/JPEG는 JpegCodec으로 분배합니다.
		PNG, FBX, PKG 등은 이후 같은 table / enum / switch 구조에
		추가할 수 있습니다.

	6. 확장자 정규화 정책 초안
		Path::GetExtension은 기존 의미를 유지해 원본 확장자를 반환합니다.

		콘텐츠 타입 판별에는 대소문자 차이를 의미 있게 보지 않으므로,
		별도의 정규화된 확장자 조회 경로를 사용합니다.

		따라서 extension table에는 .jpg / .jpeg만 등록하고,
		.JPG / .JPEG 같은 중복 항목은 넣지 않습니다.

	7. JPEG codec leaf 초안
		JpegCodec은 이미지 계열 내부의 JPEG leaf facade입니다.

		Profile Texture Bootstrap에서는 ImageCodec 계층을 별도 파일로 만들지 않고,
		Codec에서 JpegCodec으로 직접 위임하는 초안을 사용합니다.

		장기적으로 이미지 포맷이 늘어나면
		ImageCodec -> JpegCodec / PngCodec / TgaCodec 구조로
		한 단계 더 분리할 수 있습니다.

	8. PlatformJpegCodec 초안
		WIC / COM / Windows header는 Content 또는 Core에 넣지 않습니다.

		Windows WIC 구현은
		Source/Platform/Windows/Private/PlatformJpegCodec.cpp에 두고,
		HAL private header를 통해 JpegCodec이 호출하는 방향으로 정리했습니다.

		이는 File -> PlatformFile과 같은 경계 원칙입니다.

	9. RGBA8 중간 데이터 기준 초안
		JPEG decode 결과는 canonical RGBA8로 고정합니다.

		Renderer backend는 JPG bytes나 WIC를 알지 않고,
		decoded RGBA8 pixels / width / height만 받습니다.

		DecodedImageRgba8::IsValid는 중복 검증을 줄이기 위한
		임시 편의 함수로 허용하되,
		장기적으로는 이미지 검증 정책을 Image / Codec 계층으로
		이동할 수 있습니다.

	10. Renderer texture lifetime 초안
		RendererTest는 File / FileSystem / Content Codec을 통해
		CPU image fixture를 준비하고 Renderer에 제출하는 역할만 합니다.

		GPU texture 생성과 debug texture handle 설정은
		Render Thread에서만 수행합니다.

		Main Thread에서 DX11 resource를 직접 생성하지 않습니다.

	11. Renderer ABI 5 초안
		RendererModuleApi는 texture 생성과 해제를 위해
		createTextureRgba8 / destroyTexture를 추가하는 방향으로 정리했습니다.

		texture 생성은 command stream에 넣지 않습니다.
		GPU resource lifetime은 per-frame draw stream 밖에서 관리합니다.

		DrawTexturedQuad command는 texture handle만 참조합니다.

	12. 코드 스타일 보정
		새 boolean 이름은 Is / Has / Can 계열을 사용합니다.

		Should 계열 이름과 b-prefix는 사용하지 않습니다.

		기존 주석은 삭제하지 않고,
		역할이 바뀐 부분만 의미에 맞게 갱신합니다.


정리된 설계 기준
	- #2_5는 ClearRenderTarget / Present command stream까지 닫습니다.
	- Profile Texture Bootstrap은 아직 구현이 아니라 다음 작업 설계 초안입니다.
	- Core는 content file format을 알지 않습니다.
	- TextCodec은 Core에 남아 text byte <-> CString 변환만 담당합니다.
	- Content/Codec은 file type dispatch facade입니다.
	- Content/JpegCodec은 JPEG leaf facade입니다.
	- PlatformJpegCodec은 WIC 기반 Windows leaf입니다.
	- Renderer는 encoded image bytes를 알지 않습니다.
	- Renderer backend는 decoded RGBA8을 GPU texture로 업로드합니다.
	- Debug 표시 경로는 ResourceManager 도입 전 임시 bootstrap fixture입니다.


검증
	#2_5 구현 기준은 재동기화된 미러에서 ABI=4,
	RenderCommand=ClearRenderTarget/Present,
	BuildRenderCommandList가 Clear + Present를 append하는 상태로 확인했습니다.

	Profile Texture Bootstrap 실제 원본 코드 적용과 빌드는 아직 수행하지 않았습니다.

	워크벤치 미러 기준으로 #2_5 baseline과 현재 Source 구조를 확인했고,
	Profile Texture Bootstrap 구현 초안의 계층 위치와 책임 경계를 정리했습니다.


다음 작업
	Profile Texture Bootstrap 구현을 원본 프로젝트에 적용합니다.

	Source/Content 계층과 PlatformJpegCodec leaf를 추가합니다.

	RendererModuleApi ABI를 5로 올리고,
	createTextureRgba8 / destroyTexture / DrawTexturedQuad 경로를 연결합니다.

	RendererTest에서 Profile.jpg / Profile2.jpg를 로드해
	Debug x64 창에 textured quad가 표시되는지 확인합니다.
```
