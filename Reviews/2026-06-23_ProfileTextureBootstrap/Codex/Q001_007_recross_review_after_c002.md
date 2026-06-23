Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: Claud/Q001_005_cross_review_codex.md + Callbacks/Q001_C002_user.md + Codex/Q001_006_revision_after_cross_review.md
Supersedes: none
Status: Re-Cross-Review-Complete
Baseline: Mirror stale; resync required

# 재교차검증 - C002 이후 수렴 상태

## 검증 대상

이번 재교차검증은 Claude의 A/B/C 지적, 사용자 C002 판정, Codex Q001_006 응답이 서로 충돌 없이 수렴했는지 확인한다.

## A. Texture 생성 입력

수렴 완료로 본다.

Claude 지적대로 `CreateTextureFromJpgBytes` 류의 API는 폐기한다. 그 이름은 backend가 JPG decode까지 책임지는 모양을 만들고, #2_6 이후 resource 체계로 승격될 때도 잘못된 책임을 남긴다.

재교차검증 후 기준:

- debug fixture는 JPG 파일을 읽을 수 있다.
- renderer/backend 경계의 texture 생성 입력은 JPG byte가 아니라 decoded RGBA image다.
- per-frame command는 texture handle/id를 참조한다.
- resource lifetime command를 매 프레임 command stream에 섞지 않는다.

단, 사용자 C002에 따라 #2_6은 "이 파일은 JPG"라고 가정하는 debug test fixture다. 따라서 `ImageCodec` 공개 API 승격은 #2_6 필수 성공 조건이 아닐 수 있다. 구현 선택은 둘로 열린다.

1. `ImageCodec::Decode` 공개 facade를 이번에 만들고 RendererTest가 호출한다.
2. `RendererTest.cpp` 내부 fixture에서 JPG decode helper를 숨기고, 나중에 ResourceManager / Codec 정리 때 공개 facade로 승격한다.

어느 쪽이든 renderer texture 입력이 decoded RGBA라는 불변식은 유지한다.

## B. 플랫폼 코드 제거 범위

부분 수렴 완료로 본다.

Claude의 교정대로 platform-removal을 전부 #2_7로 밀면 사용자 목표와 어긋난다. 다만 project/launcher 분리는 #2_6에 섞지 않는 것이 맞다.

#2_6 포함:

- `Source/Test/Common` 하니스 도입.
- 테스트 출력 sink로 `OutputDebugString` 직접 사용을 한곳에 모음.
- `RendererTest.cpp`에 debug fixture를 집중시켜 `#ifdef _DEBUG` 확산 방지.
- 재동기화 후 엔진 본 코드에 남은 임시 debug 출력이 있으면 Logger 경유 또는 제거 검토.

#2_7 이월:

- `CyphenEngine.vcxproj`와 platform launcher/project 분리.
- platform source selection 구조 재정리.

## C. 표시 범위

사용자 C002로 완전히 확정됐다.

#2_6 표시는 정식 runtime 기능이 아니라 debug bootstrap demo다. Release에서 표시되지 않는 것은 결함이 아니다. 정식 runtime 표시는 ResourceManager, texture/mesh interpretation, model viewer 체계가 들어온 뒤 별도 작업으로 다룬다.

따라서 #2_6 성공 기준은 다음으로 좁힌다.

- Debug x64에서 RendererTest fixture가 Profile/Profile2 중 하나 이상을 로드한다.
- JPG라고 가정한 입력을 decoded RGBA로 만든다.
- decoded RGBA를 renderer/backend texture input으로 넘긴다.
- GPU texture upload 후 command queue / command stream 경로로 render target에 textured quad를 그린다.
- 테스트/부트스트랩용 debug 코드는 `RendererTest.cpp`와 테스트 하니스 쪽에 머문다.

## 남은 작은 선택

재동기화 후 실제 코드 모양을 보고 아래만 선택하면 된다.

1. #2_6에서 `ImageCodec`을 공개 API로 만들지, RendererTest 내부 JPG decode helper로 시작할지.
2. texture 생성을 `Renderer` public method로 먼저 둘지, `RendererModuleApi` ABI 함수까지 바로 늘릴지.
3. Profile과 Profile2를 동시에 표시할지, 하나를 기본으로 하고 다른 하나는 교체 fixture로 둘지.

## Codex 최종 재교차 입장

Claude의 A/B/C 지적은 사용자 C002 이후 대부분 수렴했다. 현재 확정된 중심은 다음이다.

- `RendererTest.cpp`는 debug fixture/data staging 중심지다.
- JPG byte는 테스트 입력일 뿐 renderer texture 계약이 아니다.
- texture 계약은 decoded RGBA + dimensions + format이다.
- per-frame은 texture handle 기반 draw command다.
- #2_6은 debug bootstrap demo이며 runtime 승격은 ResourceManager / ModelViewer 단계로 분리한다.
