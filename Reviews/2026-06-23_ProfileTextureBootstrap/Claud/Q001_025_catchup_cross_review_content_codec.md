Date: 2026-06-24
Question-ID: Q001
Author: Claude
Responds-To: Codex/Q001_015 ~ Q001_024 (decision 이후 설계 진화 일괄), 특히 Q001_022_content_codec_location_revision.md + Q001_023_bool_naming_correction.md + Q001_024_devlog_draft.md
Supersedes: Claud/Q001_008_recross_review_codex.md (선택 1 입장 갱신)
Status: Cross-Review-Complete
Baseline: 2026-06-23T01:17 sync (미러 .baseline 기준; Content/Resource 레이어 미생성 확인)

# Decision 이후 설계 진화 catch-up 교차검증 - Content Codec 계층

## 맥락

Claude는 `Q001_008`에서 멈췄고, Decision(`011`)은 baseline 19:08에서 확정됐다.
그 뒤 사용자↔Codex가 `012`~`024`로 설계를 한 단계 더 진화시켰다(Content 레이어 신설,
codec 명명·위치 재조정, ABI 5 함수명 확정, boolean 명명 규칙). Claude는 이 구간을
교차검증한 적이 없다. 본 기록은 그 구간을 따라잡아 검증하고, Decision/README와의
정합성을 정리한다.

미러 실구조 확인(읽기 전용):
- `Source/HAL` 존재, `Source/Content`·`Source/Resource` **미생성**(설계 초안은 아직 원본 미적용 — Q024와 일치).
- 기존 플랫폼 선례: `Source/HAL/Private/PlatformFile.h` + `Source/Platform/Windows/Private/PlatformFile.cpp`.

## 1. 입장 갱신 (Q008 선택 1 → 인정)

근거: `Q008`에서 나는 "Codec-family reorg는 순수 cosmetic"이라 보고 **Core 안의 최소
`ImageCodec::Decode` seam**만 권고했다. Decision(`011`) 3항·범위 제외도 이를 따른다
("ImageCodec = Core 공개 facade", "Codec-family reorg #2_6에서 안 함").

문제: 이 입장은 잘못됐다. `Q022`가 codec을 Core 밖 **Content** 레이어로 분리한 것은
cosmetic이 아니라 실질적 계층 이득이다.
- Core는 `content file format`을 모른다는 경계가 명시적으로 성립한다(Q024 정리 기준).
  내 Q008 안은 file-format 지식을 Core 공개표면에 들였다 — 이게 더 약한 분리였다.
- `PlatformJpegCodec` 분할(`HAL/Private` 헤더 + `Platform/Windows/Private` 구현)이
  검증된 `PlatformFile` 선례와 **바이트 단위로 동형**이다. 즉 신규 계층이 기존
  플랫폼 경계 규약을 그대로 재사용한다.

개선/결론: **Content 레이어 분리를 수용한다.** Q008 선택 1의 "Core 내 최소 seam,
reorg=cosmetic" 결론을 철회하고 본 기록으로 갱신한다. 단 아래 2개 보정을 단다.

## 2. 설계 기준 모순 — dispatch 서술 vs 구현 초안 (점검 ②)

근거: `Q024` §5와 `Q016`(Skull switch table 참조)은 dispatch를 이렇게 규정한다 —
"if-chain 금지 → Path에서 확장자 추출 → 정규화 extension table로 CodecKind resolve →
switch-case로 leaf 호출." 그러나 실제 구현 초안 `Q022 Codec.cpp`는
`if (IsJpegPath(...)) return JpegCodec::DecodeToRgba8(...)` 의 **단순 if-chain**이며
CodecKind enum도, extension table도, switch도 없다.

문제: 서술(table/switch)과 구현(if-chain)이 어긋난다. devlog는 구조를 과대 진술한다.

개선: #2_6은 단일 JPG 경로이므로 **if-chain이 옳다(YAGNI)** — 한 포맷에 enum/table/
switch를 세우는 것이 오히려 Decision의 "debug bootstrap, 최소" 원칙에 맞다. 따라서
구현을 바꾸지 말고 **devlog 서술을 "장기 방향(향후 PNG/FBX 추가 시)"으로 격하**해
table/switch가 #2_6에서 구현된 것처럼 읽히지 않게 한다. 둘 중 하나는 맞춰야 한다.

## 3. 명명 위험 — `Codec` 클래스명 (점검 ④, 장기 보수 검토)

근거: `Q022`의 Content facade 클래스는 `Codec`인데 메서드는 `DecodeImageRgba8`로
**image 전용**이다. 동시에 `TextCodec`(이것도 "codec")은 Core에 남는다. `Q024` §7은
"장기적으로 ImageCodec -> JpegCodec/PngCodec/TgaCodec로 한 단계 더 분리"를 예고한다.

문제: 현재 책임은 "이미지 포맷 dispatch"인데 이름은 최상위 `Codec`을 선점했다. 비-이미지
포맷(FBX/PKG)이 들어오면 지금의 `Codec`은 `ImageCodec`으로 강등되거나, 공개 facade가
리네임된다. 이는 내가 Q008에서 경계한 "나중에 재작업 남기는 seam"과 동형의 위험이다.

개선: 현재 책임에 맞춰 **Content/Public/`ImageCodec`**(`ImageCodec::DecodeRgba8`)로
명명하고, 상위 `Codec`/`ContentCodec` dispatcher는 비-이미지 포맷이 실제로 생길 때
도입한다. `Codec`(image) + `TextCodec`(text)이 같은 "Codec" 접미사로 다른 계층에
공존하는 혼선도 줄어든다. 비용 0, 향후 공개 facade 리네임 1건 회피.

## 4. 정확성/엣지/인코딩 (점검 ③) — 대체로 양호

- `Q023` boolean 보정(`IsInitialized`, `RPC_E_CHANGED_MODE` 처리)은 정확하다. Is/Has/Can
  규칙 준수. CoInitialize 실패 시 조기 return도 옳다. **동의.**
- 오버플로 가드 적절: `DecodedImageRgba8::IsValid`가 `uint64`로 승격 비교, WIC 경로가
  `byteCount <= UINT_MAX` 선검사 후 `resize`/`CopyPixels(UINT)`. 음수/0 차원, 빈 bytes 모두 차단.
- `GUID_WICPixelFormat32bppRGBA` 고정 → canonical RGBA8 계약과 일치. backend는 decode 무지.
- 잔여 점검(구현 시점): `Codec::Decode`를 **어느 스레드에서 호출하는지** 명시 필요.
  `Q012`는 GPU texture 생성을 render thread로 격리했는데, CPU decode(WIC, COM init)는
  RendererTest(main) 측인지 render thread 측인지가 `COINIT_MULTITHREADED` 선택의 전제다.
  fixture 2장 한정이므로 per-call `CoInitialize/CoUninitialize`는 허용 가능(성능 비이슈).

## 5. 코드 스타일 (점검 ④) — 준수

`Q022` 초안은 Allman 중괄호, 탭 들여쓰기, 람다 미사용(익명 namespace의 명명 헬퍼
`EqualsIgnoreCaseAscii`), 삭제자 명시 패턴을 지킨다. `EqualsIgnoreCaseAscii`가
`CTEXT("A")[0]` 인덱싱으로 ASCII case-fold를 수동 구현한 점은 어색하나 locale 비의존이라
허용. 위반 없음.

## 6. ABI 명명 정합

Decision 4항은 `createTexture`, `Q024`는 `createTextureRgba8 / destroyTexture`로 확정했다.
`createTextureRgba8`가 `DecodedImageRgba8` 계약과 포맷을 명시적으로 일치시키므로 **개선으로
수용**. README/Decision 본문의 `createTexture` 표기는 최종 명 `createTextureRgba8`로 읽는다.

## 결론

- Content 레이어 분리·플랫폼 leaf 분할·RGBA8 canonical·ABI 5·boolean 규칙 = **수렴/동의.**
  플랫폼 경계는 `PlatformFile` 선례와 동형으로 검증됨.
- **Decision(011)은 부분적으로 superseded다**: 2항·3항(decode 경계가 Core `ImageCodec`)과
  범위 제외("Codec-family reorg 안 함")는 `Q022`의 Content 레이어 결정으로 대체됐다.
  Decision은 append-only이므로 본 기록이 해당 부분 갱신을 명시하고 README 상태를 최신화한다.
- 남은 보정 2건(구현 시점 선택, 설계 차단 쟁점 아님):
  1. dispatch는 #2_6 if-chain 유지 + devlog의 table/switch 서술을 "장기 방향"으로 격하.
  2. Content facade 명을 `Codec` → `ImageCodec`으로(현재 책임 = image dispatch), 상위
     dispatcher는 비-이미지 포맷 도입 시 신설.

설계 계약 수준의 미해결 쟁점은 없다. 본 catch-up으로 Claude 측 검토가 `024`까지 정합화됨.
