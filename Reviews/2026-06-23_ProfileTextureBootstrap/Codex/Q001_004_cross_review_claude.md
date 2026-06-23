Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: Claude pasted response + Callbacks/Q001_C001_user.md
Supersedes: none
Status: Cross-Review-Complete
Baseline: Mirror stale; resync required

# Claude 판단 교차검증

## 검증 대상

첨부된 Claude 응답은 stale mirror를 처음에는 현재 상태처럼 읽었지만, 사용자 보정 이후 이를 임시 잔재로 낮추고 계약/계층 중심으로 설계를 다시 잡았다. 이후 핵심 제안은 다음 네 가지다.

- 테스트 트리 3분리: `Common` 하니스, `Module` 규격 테스트, `Renderer` 개별 테스트.
- JPEG decode 위치: 엔진 측 `ImageCodec`.
- `TextCodec` / `ImageCodec`을 `Codec` 패밀리로 묶고, 포맷 파서는 공개 API로 빼지 않는다.
- 플랫폼 출력 누수는 Logger 또는 테스트 출력 sink로 몰아 제거한다.

## 동의하는 부분

테스트 트리 3분리 자체는 타당하다. `Source/Test/Common`에 `TestContext`, `Expect`, 출력 sink를 두고, `Source/Test/Module`은 모듈 공통 규격, `Source/Test/Renderer`는 Renderer 도메인 테스트로 나누는 방향은 사용자 목표와 맞다.

`ImageCodec::Decode(bytes, outImage)`가 포맷 판별을 내부에서 처리해야 한다는 판단도 동의한다. 호출자가 JPEG/PNG 파서를 직접 선택할 이유는 현재 목표에 없다. 확장자보다 magic byte 기반 내부 분기가 더 안전하다.

`RendererTest.cpp`가 Renderer 테스트 데이터를 적재하는 장소가 될 수 있다는 사용자 힌트와도 충돌하지 않는다. 오히려 `Common`은 하니스, `RendererTest.cpp`는 fixture/data staging으로 역할을 나누면 된다.

## 수정이 필요한 부분

Claude의 "엔진 측 ImageCodec (Core), 구현은 Platform" 표현은 경계가 조금 위험하다. 기존 `File` / `PlatformFile` 패턴처럼 public facade와 private HAL 경계를 둔다면 가능하지만, `Core`가 이미지 디코더 구현 세부나 플랫폼 라이브러리 의존을 직접 품으면 "플랫폼 코드 제거" 목표와 반대로 간다.

더 안전한 표현은 다음이다.

- 공개 API: `Core/Public/Codec/ImageCodec.h`
- 의미 모델: `DecodedImage`는 Core 공개 타입 가능
- 구현 선택: `Core/Private/Codec/ImageCodec.cpp`가 private HAL 또는 platform-selected decoder에 위임
- 플랫폼 구현: WIC 같은 Windows 구현은 공개되지 않는 platform/private layer

즉 `ImageCodec`을 호출하는 쪽은 Core API만 보되, WIC/D3D/DXGI 같은 의존은 Core 공개 표면에 나오면 안 된다.

또 하나의 조정점은 "Frame이 디코드된 이미지를 운반한다"는 제안이다. 큰 RGBA pixel buffer를 매 프레임 `Frame`에 싣는 구조는 #2_5의 command stream 방향과 어긋날 수 있다. #2_6에서는 `RendererTest.cpp`가 bytes를 읽고 decode 가능성을 검증하더라도, 매 프레임 `Frame`에 픽셀 전체를 넣는 것은 기본안으로 삼지 않는 편이 좋다.

권장 방향은 다음과 같다.

- 테스트/부트스트랩 단계에서 `RendererTest.cpp`가 `File::ReadAllBytes`와 `ImageCodec::Decode`를 수행한다.
- decode 결과는 Renderer texture 등록/업로드 입력으로 한 번 전달한다.
- per-frame command는 `DrawTexturedQuad(textureId)`처럼 가벼운 handle/id 중심으로 둔다.
- `Frame`은 이후 Runtime/Scene snapshot이 생길 때 다시 정리한다.

## 사용자 힌트 반영

사용자 힌트의 핵심은 `RendererTest.cpp`를 단순 검증 파일이 아니라 "렌더러가 사용할 데이터들을 몰아서 적재하는 임시 지점"으로 쓰는 것이다. 이러면 테스트/부트스트랩용 `#ifdef _DEBUG`를 `Source/Test/Renderer`와 Launch의 테스트 호출부에 묶을 수 있다.

따라서 `Common` 하니스는 필요하더라도, Profile/Profile2 bytes, decode 결과, texture upload용 fixture는 `RendererTest.cpp`에 두는 편이 맞다. `Common`으로 빼야 하는 것은 출력/Expect/summary 같은 테스트 공통 기능이지, Renderer resource fixture가 아니다.

## 결론

Claude 판단은 큰 방향에서 유효하지만, 중심축을 약간 조정해야 한다.

1. `Common` 하니스는 도입 가능하다.
2. `RendererTest.cpp`는 Renderer fixture/data staging의 중심으로 둔다.
3. `ImageCodec` 공개 API는 찬성하되 WIC 같은 구현 의존은 Core 공개 표면에서 숨긴다.
4. `Frame`에 decoded pixels를 직접 싣는 방향은 보류한다.
5. #2_6의 최소 표시 경로는 "테스트/부트스트랩에서 이미지 로드·디코드 → Renderer texture 등록 → per-frame DrawTexturedQuad"로 잡는다.

## 다음 확인점

- 재동기화된 미러에서 #2_5의 `Frame`, `RenderCommand`, `RendererModuleApi` 실제 형태를 다시 확인한다.
- `ImageCodec`을 #2_6 필수 범위로 넣을지, `RendererTest.cpp` 내부 fixture에서 먼저 decode를 숨기고 다음 패치에서 공개 API로 승격할지 결정한다.
- `RendererTest.cpp`가 실제 Renderer 인스턴스까지 띄우는지, 아니면 command/texture input fixture까지만 검증하는지 범위를 정한다.
