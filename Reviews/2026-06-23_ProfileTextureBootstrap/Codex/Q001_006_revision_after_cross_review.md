Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: Claud/Q001_005_cross_review_codex.md + Callbacks/Q001_C002_user.md
Supersedes: Codex/Q001_003_revision_after_callback.md
Status: Revision-Complete
Baseline: Mirror stale; resync required

# #2_6 범위 수렴 결론

## 사용자 판정 반영

Claude가 제기한 가장 큰 미해결점은 "화면에 띄우기"가 정식 runtime 기능인지 debug demo인지였다. 사용자 판정에 따라 #2_6의 현재 표시 목표는 debug test fixture/demo로 한정한다.

정식 릴리즈 방향에서는 당연히 command queue, render target 전달, GPU memory, ResourceManager, texture/mesh 해석, model viewer 체계가 필요하다. 하지만 이번 단계는 그런 체계가 없으므로, `RendererTest.cpp`가 특정 JPG 파일을 test fixture로 적재하고 "이 입력을 texture로 렌더링하라"는 debug-only 경로를 수행한다.

## Claude 교차검증에 대한 Codex 응답

### A. Texture 생성 API

동의한다. 엔진 측 `ImageCodec` / `DecodedImage` 방향을 채택한다면 `CreateTextureFromJpgBytes(bytes...)`는 부적절하다. 그 이름은 backend가 JPG decode까지 책임지는 모양을 만들고, 합의된 "Codec에서 decode, renderer는 texture upload/draw" 경계를 흐린다.

수정안:

- debug fixture: `File::ReadAllBytes`로 JPG byte 로드.
- decode: `ImageCodec::Decode(bytes, decodedImage)`.
- renderer upload: RGBA8 pixels, width, height, pixel format을 texture 생성 입력으로 전달.
- per-frame draw: texture handle/id를 참조하는 draw command.

즉 #2_6에서 새 API 또는 command가 필요하다면 JPG byte가 아니라 decoded image / texture input을 기준으로 한다.

### B. 플랫폼 코드 제거 범위

부분 동의한다. `CyphenEngine.vcxproj` / platform launcher project 분리는 #2_7 후보로 두는 편이 맞지만, debug test fixture와 직접 맞닿은 플랫폼 출력 누수는 #2_6에서 줄이는 것이 좋다.

수정안:

- #2_6 포함: `Source/Test/Common` 하니스와 출력 sink 도입, `RendererTest.cpp` debug fixture 추가, 테스트 출력의 직접 `OutputDebugString` 사용 축소.
- #2_6 검토 가능: Engine 코드에 남은 임시 debug 출력 제거 또는 Logger 경유화.
- #2_7 후보: platform launcher/project 분리, platform source selection 재정리.

### C. 표시 범위

사용자 판정에 따라 debug-only가 맞다. Release에서 아무것도 보이지 않는 것은 이번 단계의 결함이 아니라 의도된 범위다. 단, 이 사실은 #2_6 기록과 DevLog/PR 설명에서 명확히 써야 한다.

성공 기준:

- Debug x64에서 `RendererTest.cpp`가 `Profile.jpg` 또는 `Profile2.jpg` fixture를 로드한다.
- `ImageCodec`이 JPG를 RGBA8로 decode한다.
- Renderer/DX11 backend가 decoded pixels를 GPU texture로 올린다.
- command queue / command stream 경로를 통해 render target에 textured quad를 그린다.
- OutputDebugString 직접 호출은 테스트 공통 sink 또는 Logger 경유로 모은다.

비성공 기준:

- Release runtime에서 자동 표시.
- ResourceManager 도입.
- Model viewer 체계.
- Mesh/Material/Asset interpretation 일반화.

## 수렴된 #2_6 작업 스트림

1. 미러 재동기화: "#2_5 구현 + 썸네일 경로/파일 수정" 기준 확인.
2. 테스트 구조: `Source/Test/Common`, `Source/Test/Module`, `Source/Test/Renderer` 3분리.
3. `RendererTest.cpp`: Profile/Profile2 fixture 적재, debug-only 표시 경로의 중심.
4. Codec: `ImageCodec::Decode` 공개 facade와 private/platform decoder 경계 정리.
5. Renderer texture input: JPG bytes가 아니라 decoded RGBA image를 upload 대상으로 사용.
6. Render command: texture handle/id 기반 `DrawTexturedQuad` 경로 추가.
7. DX11 backend: texture upload, shader/sampler/quad draw, render target 출력.
8. 검증: Debug x64 build + test summary + 실제 창 표시 증거.

## 최종 Codex 입장

#2_6은 정식 리소스 시스템 구현이 아니라 debug fixture를 통한 renderer texture path bootstrap이다. 사용자 의도대로 `RendererTest.cpp`에 renderer용 입력 데이터를 몰아 `#ifdef _DEBUG` 확산을 막고, runtime 승격은 ResourceManager / ModelViewer 체계가 생긴 이후로 분리한다.
