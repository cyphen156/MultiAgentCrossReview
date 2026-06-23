Date: 2026-06-23
Question-ID: Q001
Author: Claude (사용자 판정 C001/C002 + Claude↔Codex 양방향 수렴 통합)
Responds-To: 전체 Q001 기록
Supersedes: none
Status: Decision
Baseline: 2026-06-23T19:08 sync (재동기화 후 실코드 확인)

# Q001 최종 판정 - #2_6 Profile Texture Bootstrap

## 재동기화 후 검증된 베이스라인

stale mirror 잔재가 제거됐고, 아래는 실제 코드로 확인한 #2_5 + 썸네일 수정 기준이다.

- `Frame`은 `frameNumber`만 보유. 이전 `profileJpgBytes` / `profileJpgByteCount` 제거 확인. (Frame.h)
- `CyphenEngine.cpp`의 절대경로 JPG 로딩 제거 확인. 단 `OutputDebugStringA` 직접 호출은 잔존(L72, L87).
- 리소스 정규화 완료: `Resources/Thumbnail/Profile.jpg`, `Profile2.jpg` (폴더 철자·파일명 정상).
- 현재 ABI = **4**. `RendererModuleApi` = `createRenderer` / `destroyRenderer` / `executeCommandList`.
- `RenderCommandType` = `ClearRenderTarget=1`, `Present=2`만. `BuildRenderCommandList`는 `(void)currentFrame`로 프레임을 안 쓰고 Clear+Present만 append.
- backend = `Modules/Renderer/CyphenRendererDx11/`.
- 테스트는 `Source/Test/CoreIO`, `Source/Test/Module`만. Common/Renderer 없음.
- vcxproj: 플랫폼 구현 파일(`Launch.cpp`/`PlatformFile.cpp`/`WindowsString.cpp` 등)을 엔진 프로젝트가 직접 포함. 리소스 복사는 `CopyCoreIoTestResources`(Debug) 하나뿐, Thumbnail 복사 Target 없음, Profile.jpg는 프로젝트 항목 미등록.

## 확정 계약

1. **성격**: #2_6은 정식 runtime 기능이 아니라 **Debug bootstrap demo**다. Release 미표시는 의도된 범위이며 결함이 아니다. (C002)
2. **데이터 경로**: `File::ReadAllBytes`(JPG byte) → 최소 `ImageCodec::Decode`(JPG-only) → decoded RGBA. backend는 decode하지 않는다.
3. **decode 경계**: `ImageCodec`(Core 공개 facade) → platform-private decoder(WIC) 위임. WIC/D3D/DXGI는 Core 공개 표면에 노출하지 않는다. 기존 `File`→`PlatformFile` 선례와 동일.
4. **texture 생성**: `RendererModuleApi`에 `createTexture(decoded RGBA, width, height, format → handle)` / `destroyTexture(handle)` 추가 → **ABI 4→5**. GPU texture는 backend DLL 소유이고 handle 반환이 필요하므로 command stream(fire-and-forget)이 아니라 ABI 함수여야 한다. resource lifetime을 per-frame stream에 섞지 않는다.
5. **per-frame draw**: `RenderCommandType`에 `DrawTexturedQuad`(texture handle 참조) 추가. 기존 enum 값은 보존하고 append한다(`Present=2` 유지).
6. **fixture 위치**: 로딩/디코드/texture 등록은 `Source/Test/Renderer/RendererTest.cpp`의 `#ifdef _DEBUG`에 집중. 엔진 본체(`CyphenEngine.cpp`, `Frame.h`)에 테스트용 리소스 로딩을 넣지 않는다. `#ifdef _DEBUG` 확산을 RendererTest와 Launch 테스트 호출부로 제한.
7. **테스트 3분리**: `Source/Test/Common`(Expect/출력 sink/summary 하니스) / `Source/Test/Module`(모듈 공통 규격) / `Source/Test/Renderer`(Renderer fixture·command 검증).
8. **platform-removal 범위**: #2_6 = 진단/테스트 출력 누수 일원화(`CyphenEngine.cpp`의 `OutputDebugString` → Logger 경유, 테스트 출력 → Common sink). #2_7 = vcxproj/launcher project 분리, platform source selection 재정리.
9. **리소스 복사**: vcxproj에 `Resources/Thumbnail/**` Debug 복사 Target 추가 + Profile.jpg/Profile2.jpg 프로젝트 항목 등록. 절대경로 금지, OutDir 기준 상대 경로.

## 잔여 선택 확정 (저비용 권고 채택)

- **ImageCodec 승격 범위**: 최소 `ImageCodec::Decode` seam만 도입(throwaway 방지). `TextCodec`의 `Codec/` 재배치, magic-byte 포맷 분기, PNG 등 다포맷은 #2_6에서 **하지 않는다**(JPG 단일 경로).
- **두 이미지**: Profile/Profile2 둘 다 로드·등록, 기본 1장 표시 + 나머지는 교체 fixture(단일 이미지 하드코딩 아님 증거).
- **shader**: backend-internal·Windows-coupled 영역. first-light는 d3dcompiler 런타임 컴파일 inline HLSL 권고. 엔진-clean 목표에 영향 없음, 구현 시점 결정.

## 범위

- **포함**: 리소스 경로/복사, 최소 ImageCodec decode seam, ABI 4→5 texture 생성/소멸, DrawTexturedQuad, 테스트 3분리 + 출력 sink, RendererTest fixture, 진단 출력 일원화, Debug 표시 증거.
- **제외**: AssetManager / 비동기 ResourceManager, Scene/Material, model viewer, mesh/asset interpretation, Release 자동 표시, vcxproj/launcher project 분리(#2_7), Codec-family reorg·다포맷.

## 작업 순서

1. (완료) 미러 재동기화.
2. 테스트 3분리: `Common` 하니스 추출(Expect/출력 sink), `Module` 규격 유지, `Renderer` 신설.
3. vcxproj: Thumbnail 리소스 항목 등록 + Debug 복사 Target.
4. `ImageCodec::Decode`(JPG-only) + platform-private decoder(WIC) seam.
5. `RendererModuleApi` ABI 4→5: `createTexture`/`destroyTexture`. 양측(engine binder 검증 + backend export) 동시 반영.
6. `RenderCommandType`에 `DrawTexturedQuad` append + `RenderCommandBuffer`/`BuildRenderCommandList` 경로.
7. DX11 backend: RGBA → `ID3D11Texture2D`/SRV/sampler, quad VB/IB, VS/PS, Clear→DrawTexturedQuad→Present.
8. `RendererTest.cpp`: Profile/Profile2 fixture 로드·decode·texture 등록, command payload 검증.
9. 진단 출력 일원화(`OutputDebugString` → Logger / Common sink).
10. Debug x64 build + ModuleTests/RendererTests + 실제 창 표시 증거.

## 합격 기준

- Debug x64에서 `RendererTest`가 Profile/Profile2 중 하나 이상 로드.
- `ImageCodec`이 JPG를 RGBA8로 decode.
- backend가 RGBA를 GPU texture로 업로드.
- command stream 경로로 render target에 textured quad 출력 → **창에 Profile.jpg 표시 증거**.
- `OutputDebugString` 직접 호출이 Logger/Common sink로 수렴.
- ModuleTests/RendererTests 통과.

## 비합격(이번 범위 아님)

Release 자동 표시, ResourceManager, model viewer, mesh/material/asset 일반화, launcher/project 분리.

## 비고

설계 계약 수준 미해결 쟁점 없음. 본 Decision은 실제 적용 시 파일명/프로젝트 항목/ABI 현재 형태가 위 검증 베이스라인과 일치함을 전제한다. 코드 적용·빌드·커밋은 워크벤치 밖에서 사용자가 수행한다.
