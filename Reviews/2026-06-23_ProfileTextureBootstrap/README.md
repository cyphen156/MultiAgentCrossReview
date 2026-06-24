# Profile Texture Bootstrap (#2_6) 검토 요약

> 이 파일만 **가변**(현재 상태 요약). 독립 판단·교차검증·수정 결론·증거 확인은 append-only.

- **질문**: #2_6에서 프로필 JPG 리소스를 File / FileSystem으로 읽고 Renderer에 전달해 화면에 표시하며, 동시에 플랫폼 코드와 테스트 구조를 정리하는 구현 순서. (Questions/Q001.md)
- **범위**: Resource 경로 정규화, JPG byte 수명, 이미지 디코딩/텍스처 업로드 계약, Draw 최소 경로, 테스트 계층 분리, Platform 코드의 CyphenEngine 프로젝트 의존 정리.
- **제외**: 범용 AssetManager, 비동기 ResourceManager, 전체 Scene/Material 시스템, Resize/device-lost/Capability의 최종 완성.
- **Baseline**: 2026-06-23T16:59 sync

## 현재 결론 (갱신됨)

사용자 판정 반영 완료. #2_6의 현재 표시 목표는 정식 runtime 기능이 아니라 debug test fixture/demo다. 정식 릴리즈 방향에서는 ResourceManager, texture/mesh 해석, model viewer 체계가 필요하지만, 이번 단계는 `RendererTest.cpp`가 특정 JPG 파일을 fixture로 적재하고 texture upload/draw 경로를 검증하는 것으로 한정한다.

유지되는 판단: JPG 표시의 핵심은 파일 읽기 자체가 아니라 decode된 이미지 데이터를 backend texture로 만들고 Draw command로 화면에 그리는 계약이다. 단, stale mirror의 `Frame.profileJpgBytes` 구조는 기준안으로 삼지 않는다.

### 교차검증 후 수렴 (Claude↔Codex)

- **확정(C / Q001_C002)**: #2_6 표시는 **debug bootstrap demo**. 성공 기준 = Debug x64 실행에서 Profile/Profile2 fixture의 texture 표시 증거. 정식 런타임 표시는 ResourceManager + 모델뷰어 체계 이후 별도 작업.
- **수렴**: `Frame`에 per-frame decoded pixel 적재 철회 → texture 1회 등록 + per-frame `DrawTexturedQuad(handle)`.
- **수렴(A)**: texture 생성 입력은 JPG byte가 아니라 decoded RGBA + dimensions + format. `CreateTextureFromJpgBytes` 류 이름/계약은 폐기.
- **수렴(B)**: 진단/테스트 출력 누수 일원화는 #2_6, vcxproj/launcher 분리는 #2_7.
- **#2_6 단순화(C 확정 결과)**: `ImageCodec` 공개 승격은 선택 사항. 이번 단계는 JPG 가정 + `RendererTest.cpp` fixture 내부 decode 은닉도 허용하되, renderer texture 경계는 decoded RGBA로 유지한다.

## 기록 인덱스

| # | 파일 | Author | Responds-To | Status |
|---|---|---|---|---|
| 001 | Questions/Q001.md | User | none | Open |
| 002 | Codex/Q001_001_initial.md | Codex | Q001 | Initial-Complete |
| 003 | Callbacks/Q001_C001_user.md | User | Codex/Q001_001_initial.md | Callback |
| 004 | Codex/Q001_003_revision_after_callback.md | Codex | Q001_C001_user | Revision-Complete |
| 005 | Codex/Q001_004_cross_review_claude.md | Codex | Claude pasted response + Q001_C001 | Cross-Review-Complete |
| 006 | Claud/Q001_005_cross_review_codex.md | Claude | Codex/Q001_001, Q001_003, Q001_004 | Cross-Review-Complete |
| 007 | Callbacks/Q001_C002_user.md | User | Claud/Q001_005_cross_review_codex.md | Callback |
| 008 | Codex/Q001_006_revision_after_cross_review.md | Codex | Q001_005 + Q001_C002 | Revision-Complete |
| 009 | Codex/Q001_007_recross_review_after_c002.md | Codex | Q001_005 + Q001_C002 + Q001_006 | Re-Cross-Review-Complete |
| 010 | Claud/Q001_008_recross_review_codex.md | Claude | Q001_006 + Q001_007 + Q001_C002 | Re-Cross-Review-Complete |
| 011 | Decision/Q001_decision.md | Claude(통합) | 전체 Q001 | Decision |

## 06-24 재구성 (Resource 레이어 + Upload IR, 026에서 정합화) — 최신

> Codex 세션 019ef3d6 "렌더러 이미지 표시 및 리팩토링"(2026-06-24, ~07:34Z)에서 설계가 아래 "Content Codec"
> 모델을 넘어 다시 재구성됨. Claude가 026에서 catch-up 교차검증. **아직 원본 코드 미적용(설계 초안).** 세션은
> 3/4(Renderer+DX11 backend 실행)·4/4 미도달.

- **Resource 레이어 신설**(`Source/Resource`): `Resource{resourceId, kind}` + `Texture2D : Resource{format,pixels,width,height}`.
  `ResourceId`가 CPU↔GPU resource table을 잇는 logical key. **Codec은 `DecodedImageRgba8`이 아니라 `Resource&`로 decode**.
- **Codec 계층 확정**: `Content/Codec`(ResourceKind dispatch) → `Image/ImageCodec`(확장자 table+switch) →
  `Jpeg/JpegCodec`(leaf) → `Jpeg/WindowsJpegCodec`(WIC). `Path::GetExtensionLower` 신설.
  (Q025 권고였던 `Codec`→`ImageCodec` 명명·table/switch가 실현됨.)
- **Upload IR 일반화**: `CreateTexture2DCommand` 폐기 → `UploadResourceCommand{resourceId, resourceKind, payloadByteCount}`.
  RenderCommandType = Clear1/Present2/**UploadResource3/DestroyResource4/DrawTexturedQuad5**. `Texture2DUploadPayloadHeader`는
  Resource/Texture.h 소속. payload = command + header + raw pixels.
- **버퍼/인코더 분리**: `RenderCommandBuffer` 폐기 → `ModuleCommandBuffer`(운반) 직접 + 신설 `RenderCommandEncoder`(도메인 빌더).
  Texture2D 지식은 Encoder에만 격리. (ModuleCommand=운반 문법 / RenderCommand=도메인 어휘 / Backend=해석.)
- **★ ABI 결정 반전**: ResourceId를 **엔진이 선발급** → backend가 handle 반환 불요 → `createTexture`/`destroyTexture` ABI 함수
  불필요, **ABI 세대 증가 없음**. command IR을 통로로 사용. ⇒ **Decision 4항(ABI 4→5) + Claude Q008 선택 2(ABI 불가피)
  철회/대체**(Claud/Q001_026).
- **Claude 미해결 쟁점(차단 아님, 사용자/구현 시점)**: (1) `WindowsJpegCodec`을 Content에 둘지(현안) vs `Platform/Windows`에
  둘지(PlatformFile 선례) — OS-경계 불변식 결정. (2) backend는 pixel 추출 시 word 길이가 아닌 `byteCount`로 정확히 자를 것.
  (3) ResourceId 발급 주체 / upload-1회 수명 / GPU table 등록·조회 경로 미설계(3/4 이후).
- **그대로 유효**: Decision의 비-codec 계약(테스트 3분리, 출력 sink 일원화, vcxproj 리소스 복사, Debug 표시 증거).

## (구) Decision 이후 설계 갱신 (Content Codec, 025) — 026으로 대체됨

Decision(011, baseline 19:08) 확정 후 사용자↔Codex가 codec 설계를 한 단계 더 진화시켰고(012~024),
Claude가 025에서 이를 catch-up 교차검증했다. **Decision 일부가 superseded됐다:**

- **Decision 2·3항 + 범위 제외("Codec-family reorg 안 함") → 대체됨.** codec은 Core 내 `ImageCodec` seam이
  아니라 **신설 `Source/Content` 레이어**로 분리된다(Codex/Q001_022). Core는 file format을 모르고
  text 변환용 `TextCodec`만 유지한다. 구조: `Content/Codec`(dispatch facade) → `Content/JpegCodec`(leaf)
  → `HAL/Private/PlatformJpegCodec.h` + `Platform/Windows/Private/PlatformJpegCodec.cpp`(WIC). 이 플랫폼
  분할은 기존 `PlatformFile` 선례와 동형으로 검증됨(Claud/Q001_025).
- **boolean 명명**: 신규 boolean은 `Is/Has/Can`만, `should`/`b`-prefix 금지(Codex/Q001_023).
- **ABI 5 함수명 확정**: `createTextureRgba8 / destroyTexture`(Decision 본문의 `createTexture` 표기 갱신).
- **Claude 보정 2건(구현 시점, 차단 쟁점 아님)**: (1) dispatch는 #2_6 단일 JPG라 if-chain 유지하되
  devlog의 "extension table→CodecKind→switch" 서술은 장기 방향으로 격하(서술/구현 불일치 해소).
  (2) Content facade 명을 `Codec`→`ImageCodec`으로(현재 책임=image dispatch), 상위 dispatcher는
  비-이미지 포맷 도입 시 신설.
- **적용 상태**: 위 설계는 아직 원본 코드 미적용(미러에 `Source/Content` 미생성). devlog 초안만 존재(024).

## 최종 판정

**확정 (Decision/Q001_decision.md). 단 codec 부분은 위 "Decision 이후 설계 갱신"으로 대체.** 재동기화(2026-06-23T19:08) 후 실코드로 베이스라인 검증 완료 — stale 잔재 제거 확인(Frame=frameNumber만, JPG 로딩 제거), 리소스 정규화 완료(Resources/Thumbnail/Profile.jpg·Profile2.jpg), ABI=4, RenderCommand=Clear/Present만, 플랫폼 파일 엔진 vcxproj 직접 포함, Thumbnail 복사 Target 없음.

#2_6 확정 계약: (1) Debug bootstrap demo, Release 미표시는 의도 (2) File::ReadAllBytes → 최소 ImageCodec::Decode(JPG-only) → RGBA, backend는 decode 안 함 (3) ImageCodec 공개 facade→platform-private(WIC) 위임 (4) RendererModuleApi.createTexture/destroyTexture, ABI 4→5 (5) DrawTexturedQuad append(Present=2 보존), resource는 stream 밖 (6) RendererTest.cpp(_DEBUG) fixture 중심 (7) 테스트 3분리(Common/Module/Renderer) (8) 출력 누수 일원화=#2_6, launcher 분리=#2_7 (9) Thumbnail 복사 Target 추가. 합격 기준 = Debug x64에서 창에 Profile.jpg 표시 증거.

### 구현 보정

Codex 구현 초안 보정 추가(Q001_012): `RendererTest.cpp`는 CPU fixture 적재와 제출까지만 담당하고, GPU texture 생성/해제 및 debug texture handle 설정은 render thread에서 수행한다. Profile/Profile2 둘 다 로드, `FileSystem::FileExists` + `File::ReadAllBytes` 사용, `destroyTexture`는 `destroyRenderer` 전에 호출한다.

| 012 | Codex/Q001_012_implementation_correction.md | Codex | Claude implementation drift/threading review | Implementation-Correction |
| 014 | Codex/Q001_014_type_unification_after_threading_review.md | Codex | Claude threading correction review | Implementation-Correction |
| 015 | Codex/Q001_015_codec_scope_correction.md | Codex | User codec scope correction | Implementation-Correction |
| 016 | Codex/Q001_016_skull_codec_switch_table.md | Codex | User reference to Skull ContentRecordCodec.cs | Implementation-Correction |
| 017 | Codex/Q001_017_codec_direct_call_is_temporary.md | Codex | User resource-manager direction correction | Implementation-Correction |
| 018 | Codex/Q001_018_codec_rename_confirmed.md | Codex | User codec rename confirmation | Implementation-Correction |
| 019 | Codex/Q001_019_codec_leaf_stb_now_turbo_later.md | Codex | User performance criterion + Claude codec leaf critique | Implementation-Correction |
| 020 | Codex/Q001_020_codec_platform_leaf_final.md | Codex | User correction: platform code must not be pulled into Core Codec | Implementation-Correction |
| 021 | Codex/Q001_021_full_2_6_implementation_draft.md | Codex | User request: show full #2_6 implementation code | Implementation-Draft |
| 022 | Codex/Q001_022_content_codec_location_revision.md | Codex | User decision: Codec belongs under Content, not Core/Resource/Module | Implementation-Draft |
| 023 | Codex/Q001_023_bool_naming_correction.md | Codex | User correction: boolean names must use Is/Has/Can, not Should or b-prefix | Implementation-Correction |
| 024 | Codex/Q001_024_devlog_draft.md | Codex | User request: DevLog draft after #2_6 design convergence | DevLog-Draft |
| 025 | Claud/Q001_025_catchup_cross_review_content_codec.md | Claude | Codex/Q001_015~024 (Content codec 진화) | Cross-Review-Complete |
| 026 | Claud/Q001_026_catchup_resource_layer_and_upload_ir.md | Claude | Codex 세션 019ef3d6 (06-24: Resource 레이어/Upload IR/Encoder) | Cross-Review-Complete |
