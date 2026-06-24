Date: 2026-06-24
Question-ID: Q001
Author: Claude
Responds-To: Codex 세션 019ef3d6 "렌더러 이미지 표시 및 리팩토링" 2026-06-24 구간(07:34Z까지) — Resource 레이어 신설, Codec→Resource decode, UploadResource IR, RenderCommandEncoder 분리
Supersedes: Claud/Q001_025_catchup_cross_review_content_codec.md (Content codec 모델 갱신), Claud/Q001_008_recross_review_codex.md 선택 2(ABI 4→5 불가피 주장) 철회
Status: Cross-Review-Complete
Baseline: Codex 로컬 세션(019ef3d6) 기준 설계 초안. 원본/미러 미적용(Source/Resource·Content 미생성). 워크벤치 미러 .baseline=2026-06-23T01:17.

# 06-24 설계 진화 catch-up — Resource 레이어 + Upload IR + Encoder 분리

## 출처/성격

Decision(011)과 Claude Q025는 "Core/Content codec + DecodedImageRgba8 + ABI 4→5 createTexture"
모델이었다. 그러나 06-24 Codex 세션(019ef3d6)에서 사용자↔Codex가 설계를 그 너머로
재구성했다. 본 기록은 그 세션 구간을 따라잡아 검증한다. 아직 원본 코드 미적용(설계 초안).
세션은 3/4(Renderer+DX11 backend 실행), 4/4 미도달 — 계약은 수렴, backend 실행부는 미초안.

## 06-24 수렴 계약 (요지)

1. **Resource 레이어 신설**(`Source/Resource`): `Resource{ resourceId:uint64, kind:ResourceKind }`
   베이스 + `Texture2D : Resource { format, pixels, width, height }`(CPU-side). `ResourceId`는
   CPU Resource Table ↔ GPU Resource Table을 잇는 logical key. hot path는 ResourceId만 운반.
2. **Codec이 Resource로 decode**: `Codec::Decode(path, bytes, Resource& out)` 다형. 계층:
   `Content/Codec`(ResourceKind dispatch) → `Content/Private/Image/ImageCodec`(확장자 table+switch)
   → `.../Jpeg/JpegCodec`(leaf) → `.../Jpeg/WindowsJpegCodec`(WIC provider). `Path::GetExtensionLower` 신설.
3. **Upload IR 일반화**: `CreateTexture2DCommand` 폐기 → `UploadResourceCommand{ resourceId,
   resourceKind, payloadByteCount }`. RenderCommandType = None0/Clear1/Present2/**UploadResource3/
   DestroyResource4/DrawTexturedQuad5**. `Texture2DUploadPayloadHeader{format,width,height,byteCount}`는
   Resource/Texture.h 소속. payload = UploadResourceCommand + Texture2DUploadPayloadHeader + raw pixels.
4. **버퍼/인코더 분리**: `RenderCommandBuffer` 폐기 → `ModuleCommandBuffer`(ABI-safe word stream
   저장만) 직접 사용 + 신설 `RenderCommandEncoder`(static: AppendClear/Present/UploadResource/
   DestroyResource/DrawTexturedQuad(ModuleCommandBuffer&,...)). Texture2D 지식은 Encoder에만 격리.
5. **계층 의미**: ModuleCommand=공통 운반 문법(commandType은 숫자), RenderCommand=Renderer 도메인
   어휘(enum/payload). 모듈별 command namespace 충돌 방지(Renderer 1=Clear vs Audio 1=SubmitSamples).

## 검토 — 동의(근거 포함)

- **Resource 베이스 + Texture2D 상속 + ResourceId 키**: hot path(ResourceId) / cold path(payload)
  분리가 깨끗하다. 동의.
- **UploadResource 일반화(C 폐기)**: enum 폭증(CreateTexture2D/Mesh/Buffer…) 방지. backend가
  resourceKind로 분기하는 게 그래픽스 API 차이(텍스처 vs 버퍼 생성)와도 맞는다. 사용자가 끌어낸
  방향이 옳다. 동의.
- **RenderCommandBuffer 폐기 + Encoder 분리**: "버퍼가 Texture2D를 알면 안 된다"는 사용자 지적이
  정확하다. 운반(ModuleCommandBuffer) / 도메인 빌더(Encoder) / 해석(Backend) 3분리는 #2_5
  ModuleCommand 설계 의도와 정합. 동의.
- **ImageCodec 확장자 table+switch 구현**: Q025 #2에서 지적한 "devlog 서술(table/switch) vs 구현
  (if-chain)" 불일치가 해소됐다. 그리고 Q025 #1 권고(`Codec`→`ImageCodec` 명명)가 더 나은 형태로
  실현됨 — `Codec`(top) / `ImageCodec`(image dispatch) / `JpegCodec`(leaf) 3층. 동의.

## 검토 — 입장 철회 (Q008 선택 2)

근거: Q008 선택 2에서 나는 "GPU texture handle을 반환해야 per-frame draw가 참조하므로 fire-and-forget
command stream으로는 안 되고 `createTexture`/`destroyTexture` ABI 함수가 불가피, ABI 4→5"라고
단언했다. Decision 4항도 이를 채택했다.

문제: 이 전제가 틀렸다. 06-24 설계는 **ResourceId를 엔진이 선발급**하고 backend가 그 키로 GPU
resource table에 등록하는 구조다. 즉 backend가 handle을 **반환할 필요가 없다** — 엔진이 이미 key를
안다. 따라서 `UploadResource(ResourceId,…)` / `DrawTexturedQuad(ResourceId)` 모두 fire-and-forget
command stream으로 충분하고, **ABI 함수 추가도 ABI 세대 증가도 불필요**하다.

개선/결론: Q008 선택 2와 **Decision 4항(ABI 4→5 createTexture)을 철회/대체**한다. command IR을
통로로 쓰고 ABI를 고정하는 06-24 방향이 "RendererModuleApi를 늘리지 않는다"는 본래 목표와도 일치한다.
이게 이번 catch-up에서 가장 중요한 정정이다.

## 검토 — 제기할 쟁점

### 쟁점 1 (점검 ① 계층) — WindowsJpegCodec의 Content 배치

근거: Q022/Q025에서 WIC 구현은 `HAL/Private/PlatformJpegCodec.h` + `Platform/Windows/Private/
PlatformJpegCodec.cpp`로, 검증된 `PlatformFile`(`HAL/Private/PlatformFile.h` + `Platform/Windows/
Private/PlatformFile.cpp`) 선례와 동형이었다. 06-24에선 `Content/Private/Image/Jpeg/
WindowsJpegCodec.cpp`로 옮기고 "HAL/Platform 추상화가 아니라 Content JPEG provider"로 규정했다.

문제: 이제 Windows 전용 코드(`#include <wincodec.h>`, COM)가 `Source/Content/` 안에 산다. "OS API는
Platform/HAL 뒤에 격리한다"는 기존 불변식(File→PlatformFile)이 codec 계열에서 깨진다. 비-Windows
빌드는 이 .cpp를 제외하고 다른 provider를 끼워야 하는데, 그 선택 지점이 Platform 트리가 아니라 Content
트리 내부로 들어간다.

개선: 둘 중 하나로 **명시 결정** 필요.
(a) 보수안 — WIC leaf를 `Platform/Windows/Private`에 두고 build per-platform 선택(File 선례 유지).
    JpegCodec이 HAL private header로 호출. 일관성 우선.
(b) 수용안 — "codec provider는 포맷 계열과 함께 살 수 있고 platform-specific일 수 있다"를 새 불변식으로
    문서화. 단 이때도 platform 분기(어느 provider를 컴파일할지)는 vcxproj/빌드에서 명확히.
나는 (a)를 약하게 선호(기존 OS-경계 불변식 유지)하나, JPEG provider 응집 관점의 (b)도 근거가 있다.
설계 차단 쟁점은 아니며 사용자 판정 사항.

### 쟁점 2 (점검 ③ 정확성) — backend payload 추출 시 byteCount 사용

근거: ModuleCommand는 64-bit word 단위(padding)로 운반하고, `payloadWordCount`로 길이를 표현한다.
그러나 raw pixel bytes는 8의 배수가 아닐 수 있다. `UploadResourceCommand.payloadByteCount` /
`Texture2DUploadPayloadHeader.byteCount`가 정확 바이트 수를 별도로 들고 있다.

문제(3/4 backend 초안 시 주의): backend는 pixel을 꺼낼 때 `wordCount*8`이 아니라 **header.byteCount**로
정확 길이를 잘라야 한다. word padding 잔여 바이트를 픽셀로 오해하면 안 된다.

개선: ExecuteUploadTexture2D에서 `byteCount` 기준 복사 + `width*height*4 == byteCount` 재검증.
RenderCommandBuffer(현 ModuleCommandBuffer) 쪽 IsValid 검사는 이미 그 등식을 본다 — backend도 동일 검사.

### 쟁점 3 (점검 ② 설계 기준) — upload 1회 수명 / ResourceId 발급 주체 미설계

근거: Frame은 `texturedQuadDrawItems`(ResourceId)만 든다. upload/destroy는 "Frame이 아니라 별도
pending resource 경로에서 command로 변환"한다고 규정됐다(06-24, Q024 일치).

문제: 그 pending 경로, **ResourceId 발급 주체**, "upload 1회 후 여러 frame draw" 수명 보장, GPU
resource table 등록/조회 규약이 아직 초안에 없다(3/4 이후). UploadResource를 매 frame 보내면 안 되고,
DrawTexturedQuad가 참조하는 ResourceId가 backend table에 이미 resident임이 보장돼야 한다.

개선: 3/4에서 (1) ResourceId 발급자(엔진 측 단일 권한) (2) upload는 pending 큐에서 1회 (3) draw 이전
순서 보장 (4) destroy 시점을 명시할 것. #2_6 fixture(Profile/Profile2)는 부팅 시 1회 upload면 충분.

## 결론

06-24 재구성(Resource 레이어 / Codec→Resource / UploadResource IR / Encoder 분리 / ABI 고정)은
방향이 옳다. 대부분 동의하며, **Decision 4항(ABI 4→5)과 Q008 선택 2를 철회**하는 것이 본 catch-up의
핵심이다(ResourceId 선발급으로 handle 반환 불요 → ABI 불변).

미해결(설계 차단 아님, 사용자/구현 시점): 쟁점1(WindowsJpegCodec 계층 배치 a/b 결정), 쟁점2(backend
byteCount 추출), 쟁점3(ResourceId 발급·upload 수명 경로). 3/4·4/4(backend 실행, shader/quad,
RendererTest fixture)와 Decision의 비-codec 계약(테스트 3분리, 출력 sink 일원화, vcxproj 리소스 복사)은
이번 06-24 논의에서 다루지 않았고 그대로 유효하다.

이로써 Claude 측 검토가 06-24T07:34Z 세션 상태까지 정합화됨.
