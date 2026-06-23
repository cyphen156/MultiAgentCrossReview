Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: Callbacks/Q001_C001_user.md
Supersedes: Codex/Q001_001_initial.md
Status: Revision-Complete
Baseline: Mirror stale; resync required

# #2_6 Profile JPG 표시 수정 결론

## 수정 이유

Codex/Q001_001_initial.md는 현재 워크벤치 미러의 `Frame.profileJpgBytes`와 `CyphenEngine.cpp` 임시 JPG byte 전달 코드를 기준 증거로 삼았다. 사용자 Callback에 따르면 이 코드는 이전 대화의 잔재이며, 실제 기준 상태는 롤백 후 다시 미러를 떠야 한다.

따라서 Q001_001의 "이미 JPG byte를 Frame에 싣는 임시 흔적이 있다"는 현상 판단은 폐기한다. 남길 수 있는 결론은 더 좁다.

## 현재 유효 기준

- #2_5 구현은 유지된 기준으로 본다.
- 썸네일 경로와 파일 수정은 적용된 기준으로 본다.
- 재동기화 전의 현 미러 내용은 #2_6 구현 세부 근거로 사용하지 않는다.
- #2_6 목표는 여전히 `File` / `FileSystem` 등 엔진 공개 API로 썸네일 JPG를 읽고, Renderer로 전달해 화면에 띄우는 것이다.

## 수정된 구현 순서

1. 원본 기준으로 미러를 다시 동기화한다.
2. 동기화 후 `Resources/Thumbnail/Profile.jpg`, `Profile2.jpg` 또는 실제 적용된 최종 경로/파일명을 확인한다.
3. #2_5의 Frame -> RenderCommand -> backend command stream 구조가 그대로 유지되는지 확인한다.
4. JPG byte 로딩은 `File::ReadAllBytes`를 사용하되, 절대경로가 아니라 동기화된 Resource root 기준 상대 경로를 사용한다.
5. Renderer로 넘길 데이터 계약을 새로 설계한다. 이전 잔재인 `Frame.profileJpgBytes` 포인터 구조는 기본안으로 채택하지 않는다.
6. Texture 생성/업로드와 Draw 명령은 `Clear/Present` 이후의 새 Renderer command로 추가한다.
7. `Source\Test\Renderer\RendererTest.*`를 별도 생성해 Renderer domain command 생성과 validation을 검증한다.
8. `Source\Test\Module\ModuleTest.*`는 모듈 공통 command/binder 규격 테스트로 남기고, 실제 Renderer 테스트는 RendererTest로 분리한다.

## 구조 리팩토링 범위 조정

`CyphenEngine` 내부 플랫폼 코드 제거는 #2_6 이미지 표시와 동시에 완결할 경우 범위가 커질 수 있다. 다만 재동기화 후에도 `CyphenEngine.vcxproj`가 platform 구현 파일을 직접 포함하고 있다면, 이번 검토에서는 다음처럼 나누는 편이 좋다.

- #2_6 필수: 테스트 코드 위치와 역할 분리, RendererTest 추가, Resource 경로/복사 정책 정리.
- #2_6 선택: platform launcher 분리의 작은 첫 단계가 가능한지 확인.
- #2_7 후보: `CyphenEngine` core project와 platform launcher/build selection 분리.

## 폐기된 근거

다음 근거는 stale mirror에 기반하므로 Q001 이후 판단의 기준에서 제외한다.

- `CyphenEngine.cpp`가 Profile JPG를 절대경로로 읽는다는 판단.
- `Frame`에 `profileJpgBytes`와 byte count가 이미 들어와 있다는 판단.
- `Renderer::BuildRenderCommandList`가 JPG byte 존재만 검사한다는 판단.

## 유지되는 결론

JPG 표시의 본질은 파일 읽기 자체가 아니라 decode된 이미지 데이터를 backend texture로 만들고 Draw command로 화면에 그리는 것이다. 다만 그 계약은 stale mirror의 임시 `Frame` 포인터 구조가 아니라, 재동기화된 #2_5 구조 위에서 다시 잡아야 한다.
