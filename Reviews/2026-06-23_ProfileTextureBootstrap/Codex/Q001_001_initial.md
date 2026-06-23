Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: Q001
Supersedes: none
Status: Initial-Complete
Baseline: 2026-06-23T16:59 sync

# #2_6 Profile JPG 표시와 구조 정리 초기 판단

## 현재 코드 상태

이미 "JPG를 읽어서 Frame에 싣는" 임시 흔적은 들어와 있다. `CyphenEngine.cpp`는 `File::ReadAllBytes`로 `C:\Project\CyphenEngine\CyphenEngine\Resources\Thumbnail\Profile.jpg`를 읽고, `profileJpgBytes.data()`와 byte count를 매 프레임 `Frame`에 넣는다.

하지만 실제 미러 리소스는 `Resources\Thumnail\프사.jpg`, `Resources\Thumnail\프사2.jpg`이며, 질문의 `Resources/Thumbnaiil/Profile.jpg`, `Profile2.jpg`와 일치하지 않는다. 이 상태에서는 경로 문자열만 고쳐도 원본/미러/빌드 출력 간 재현성이 흔들린다.

Renderer 계약은 아직 이미지 표시 계약이 아니다. `Frame`에는 `profileJpgBytes`와 `profileJpgByteCount`가 있지만, `Renderer::BuildRenderCommandList`는 null/size만 검사하고 Clear/Present만 append한다. DX11 backend도 `RenderCommandType::ClearRenderTarget`과 `Present`만 해석한다. 즉 #2_6의 실제 핵심은 "byte 전달"이 아니라 "이미지 decode 결과를 backend texture로 업로드하고 최소 quad draw command로 화면에 올리는 계약"이다.

## 결론

#2_6은 한 번에 구조를 크게 갈아엎기보다 네 개의 작은 패치로 쪼개는 편이 좋다.

1. 리소스 경로와 복사 정책 정리.
2. JPG byte 로딩 수명 정리.
3. Renderer 테스트 분리.
4. 최소 Texture/Draw 명령 추가.

이 순서가 좋은 이유는 경로/파일명 불일치와 테스트 구조를 먼저 고정하지 않으면, DX11 텍스처 업로드 실패가 파일 로딩 문제인지 렌더 경로 문제인지 분리하기 어렵기 때문이다.

## 패치 1 - Resource 경로 정규화

먼저 리소스 이름을 프로젝트 기준 경로로 고정해야 한다. 현재 절대경로 `C:\Project\...`는 원본 레포 위치에 묶여 있으므로 제거 대상이다.

제안:

- 리소스 폴더명을 `Resources\Thumbnail`로 정규화한다. 현재 `Thumnail`, 질문의 `Thumbnaiil` 모두 오타 가능성이 높다.
- 파일명을 `Profile.jpg`, `Profile2.jpg`로 정규화한다. 한글 파일명 자체가 문제는 아니지만, 지금 질문의 목표와 실제 파일명이 달라 리뷰/빌드/복사 정책에서 계속 흔들린다.
- `.vcxproj`의 build target에 Thumbnail 리소스 복사를 추가한다. 현재는 `Resources\Test\CoreIo`만 Debug 출력으로 복사한다.
- 엔진에서는 실행 파일 기준 또는 이후 Resource root 정책 기준의 상대 경로를 사용한다. 이번 단계에서 `FileSystem`은 존재/크기 확인용으로만 쓰고, 실제 byte 로드는 `File::ReadAllBytes`가 맡는 것이 현재 책임 경계와 맞다.

주의: 이 단계에서 AssetManager를 만들 필요는 없다. `File` / `FileSystem` 공개 API를 통한 최소 bootstrap으로 충분하다.

## 패치 2 - JPG byte 수명과 Frame 입력 정리

현재 `Frame`이 raw pointer를 들고 있고 `CyphenEngine`의 `std::vector<uint8>` storage가 엔진 생명주기 내내 살아 있으므로 당장 dangling은 아니다. 다만 이 구조는 "Renderer가 JPG를 매 프레임 다시 해석할 수도 있다"는 잘못된 압력을 만든다.

제안:

- `CyphenEngine`은 bootstrap에서 두 파일을 읽어 보관한다.
- 첫 프레임 또는 resource bootstrap frame에만 이미지 byte를 전달한다.
- Renderer는 byte를 command stream에 매번 싣지 않는다. `CreateTexture2D` 같은 resource 생성 command 또는 별도 renderer-side bootstrap method가 필요하다.
- decoded image는 Renderer/Backend 경계 근처에서 정한다. WIC 사용 여부를 정해야 하며, DX11 전용 WIC decode를 backend에 둘지, 엔진 공통 ImageDecoder를 둘지 별도 판단이 필요하다.

Codex 쪽 1차 선호는 "이번 #2_6에서는 DX11 backend 내부 WIC decode + texture upload로 최소 표시를 먼저 증명"이다. 공통 ImageDecoder 추상화는 OpenGL ES/Vulkan로 같은 이미지가 넘어가는 시점에 빼도 늦지 않다.

## 패치 3 - 테스트 구조 분리

현재 `Source\Test\Module\ModuleTest.cpp`는 `ModuleCommandBuffer` 같은 모듈 공통 command carrier 테스트에 가깝다. 이름은 `ModuleTests`지만 실제 Renderer domain test와 섞이면 역할이 흐려진다.

제안:

- `Source\Test\Module\ModuleTest.*`는 "모듈 공통 규격 테스트"로 유지하거나 `ModuleCommandTests` 성격을 명확히 한다.
- Renderer 명령/Frame 변환 테스트는 `Source\Test\Renderer\RendererTest.*`로 분리한다.
- Launch의 Debug test 호출은 `RunModuleTests(); RunRendererTests();`처럼 나란히 둔다.
- RendererTest의 첫 검증 대상은 GPU 실행이 아니라 `RenderCommandBuffer` / `BuildRenderCommandList`가 의도한 command를 만드는지다. GPU/창 의존 테스트는 나중에 수동 실행 증거로 분리하는 편이 낫다.

이 방향은 "Test/Module은 모듈에 관한 테스트 규격화, 실제 모듈 테스트는 개별 모듈 테스트로 분화"라는 사용자 목표와 맞다.

## 패치 4 - 최소 Texture/Draw 명령

이미지 표시를 위해 필요한 최소 command는 Clear/Present만으로 부족하다.

최소 후보:

- `CreateTexture2DFromJpgBytes` 또는 더 일반적인 `UploadTexture2D`.
- `DrawTexturedQuad`.
- `Present`.

다만 현재 `ModuleCommandList`는 한 프레임 실행 command stream이며, resource lifetime command와 per-frame draw command를 같은 stream에 넣을지 조심해야 한다. #2_6에서는 임시로 renderer bootstrap 단계에서 texture를 한 번 만들고, 매 프레임은 `DrawTexturedQuad(textureId)`만 보내는 쪽이 낫다.

DX11 구현 최소 작업:

- WIC로 JPG decode.
- `ID3D11Texture2D` + `ID3D11ShaderResourceView` 생성.
- fullscreen 또는 중앙 quad용 vertex buffer / index buffer / sampler / vertex shader / pixel shader 추가.
- BackBuffer RTV를 bind하고 viewport를 설정한 뒤 Clear -> Draw -> Present 실행.

이때 shader를 어디에 둘지도 정해야 한다. 첫 단계는 C++ string으로 내장하거나 precompiled bytecode를 리소스로 두는 두 가지가 있는데, 검토 가능성과 빌드 단순성만 보면 C++ 내장 HLSL compile은 편하지만 `d3dcompiler` 의존을 추가한다. 더 보수적인 선택은 아주 작은 precompiled shader blob 또는 별도 shader 파일 복사 정책을 명시하는 것이다.

## 플랫폼 코드 제거 판단

"CyphenEngine 내부 플랫폼 코드 제거"는 의미를 정확히 나눠야 한다.

- `Source\Platform\Windows\Private\Launch.cpp` 같은 플랫폼 진입점은 애플리케이션 프로젝트에 남아 있을 수 있다. 완전히 제거하면 현재 exe entry와 window 생성 책임이 사라진다.
- 제거해야 할 것은 Core/Engine/Modules가 플랫폼 구현 파일을 직접 끌어안는 구조, 그리고 `CyphenEngine.vcxproj`가 Windows 구현과 Linux excluded stub을 동시에 품고 있는 빌드 구조다.
- 다음 구조 목표는 `CyphenEngine` core project와 platform launcher project 분리 또는 platform source selection을 빌드 레벨에서 명확히 하는 것이다.

따라서 #2_6에서 "플랫폼 코드 제거"를 이미지 표시와 동시에 완결하려 하면 범위가 너무 커진다. 이번에는 테스트 이동/RendererTest 분리와 리소스 복사 정책만 먼저 고치고, platform launcher project 분리는 별도 #2_7급 작업으로 두는 편이 안전하다.

## 적용 순서 제안

1. `Resources\Thumbnail\Profile.jpg`, `Profile2.jpg` 명명과 build output 복사를 먼저 고정한다.
2. `CyphenEngine.cpp`의 절대경로 로딩을 제거하고 상대 resource root 기반 `File::ReadAllBytes`로 바꾼다.
3. `Source\Test\Renderer\RendererTest.*`를 만들고 `RenderCommandBuffer` / renderer command 생성 테스트를 ModuleTest에서 분리한다.
4. Renderer command에 texture/bootstrap 최소 계약을 추가한다.
5. DX11 backend에 JPG decode + texture upload + textured quad draw를 추가한다.
6. Debug x64 build, ModuleTests, RendererTests, 실제 창에서 Profile/Profile2 표시를 증거로 확인한다.

## 남은 질문

- Profile과 Profile2를 동시에 표시해야 하는가, 아니면 둘 중 하나를 교체 테스트로 표시하면 되는가?
- 이미지 decoder는 #2_6에서 DX11 backend 내부 WIC로 한정해도 되는가?
- `CyphenEngine` 플랫폼 코드 제거는 이번 작업의 필수 완료 조건인가, 아니면 구조 분리 계획 기록까지가 이번 범위인가?

현재 Codex 판단은 "Profile 표시를 먼저 작게 증명하고, 플랫폼 launcher 분리는 다음 구조 작업으로 넘긴다"이다.

## 근거

- `CyphenEngine/Source/Engine/Private/CyphenEngine.cpp`: `File::ReadAllBytes`로 절대경로 Profile JPG를 읽고 `Frame`에 raw pointer를 넣는다.
- `CyphenEngine/Source/Modules/Renderer/Public/Frame.h`: 현재 Frame은 JPG byte pointer/count만 가진다.
- `CyphenEngine/Source/Modules/Renderer/Private/Renderer.cpp`: `BuildRenderCommandList`는 byte 존재만 검사하고 Clear/Present만 append한다.
- `Modules/Renderer/CyphenRendererDx11/Source/Private/Dx11Renderer.cpp`: backend parser는 ClearRenderTarget/Present만 처리한다.
- `CyphenEngine/CyphenEngine.vcxproj`: test resource 복사는 CoreIo Debug resource에 한정되어 있고 Thumbnail resource 복사는 없다.
- `CyphenEngine/Source/Test/Module/ModuleTest.cpp`: 현재 ModuleTest는 module command carrier 테스트이며 Renderer domain 테스트가 아니다.
