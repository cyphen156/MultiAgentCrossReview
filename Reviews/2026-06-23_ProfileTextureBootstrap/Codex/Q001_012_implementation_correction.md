Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: Claude implementation drift/threading review
Supersedes: none
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 구현 초안 보정 - 스레딩과 목표 드리프트

## 판정

Claude의 구현 구조 점검은 타당하다. 특히 `RendererTest.cpp`에서 `renderer.CreateTexture2DRgba8(...)`를 직접 호출하는 초안은 D3D11 immediate context / renderer handle 소유 스레드 경계를 흐린다. #2_6은 texture upload를 renderer thread 안에서 수행하도록 보정해야 한다.

## 최초 목표 대비 드리프트 보정

다음 항목은 #2_6 구현에서 빠지면 원래 목표를 충족하지 못한다.

1. `Profile.jpg`와 `Profile2.jpg` 둘 다 fixture로 로드한다.
2. `FileSystem::FileExists`로 존재 확인 후 `File::ReadAllBytes`를 호출한다.
3. 출력 누수 정리(`OutputDebugString` 직접 호출 축소 / 테스트 출력 sink)를 Stage C에서 실제로 처리한다.

`PlatformImageDecoder.cpp`의 WIC 구현은 `Source/Platform`에 격리되는 platform-private 구현이므로 "플랫폼 코드 제거" 목표와 충돌하지 않는다. 제거 대상은 platform 구현 그 자체가 아니라 Engine/Test 상위 계층에 새는 직접 platform 호출이다.

## 스레딩 보정

GPU texture 생성과 debug texture handle 설정은 renderer thread에서 수행한다.

잘못된 흐름:

```text
Main thread RendererTest
    File read
    Decode
    renderer.CreateTexture2DRgba8(...)
        -> backend createTextureRgba8(...)
```

이 흐름은 main thread가 backend GPU resource 생성을 호출하게 만들고, render thread의 command 실행과 동시 접근할 수 있다. 또한 debug texture 멤버를 main thread가 쓰고 render thread가 읽는 race가 생긴다.

수정된 흐름:

```text
Main thread RendererTest
    FileSystem::FileExists
    File::ReadAllBytes
    ImageCodec::DecodeRgba8
    renderer.SubmitDebugTextureSource(profileImage, profile2Image)

Render thread Renderer::Run
    createRenderer
    submitted CPU image drain
    moduleApi.createTextureRgba8(...)
    debug Texture2D handle 저장
    per-frame BuildRenderCommandList
        DrawTexturedQuad(debugTexture.handle)

Render thread shutdown
    moduleApi.destroyTexture(debugTexture.handle)
    moduleApi.destroyRenderer(rendererHandle)
```

`RendererTest.cpp`는 임시 ResourceManager 역할을 하되, 그 책임은 CPU-side fixture 적재와 제출까지다. GPU resource 소유와 생성/해제는 renderer/backend가 끝까지 가진다.

## lifetime 보정

`destroyTexture` 호출은 필수다. 순서는 renderer thread에서 다음을 따른다.

1. frame input stop / render loop 종료
2. debug texture가 있으면 `moduleApi.destroyTexture(rendererHandle, textureHandle)`
3. `moduleApi.destroyRenderer(rendererHandle)`

즉 texture lifetime은 renderer lifetime보다 짧고, 같은 backend renderer handle 안에서 생성/소멸된다.

## 구현 API 보정안

RendererTest에서 직접 GPU texture를 만들지 않기 위해 #2_6의 debug API는 다음처럼 CPU source 제출 형태가 낫다.

```cpp
struct Texture2DSourceRgba8
{
	std::vector<uint8> pixels;
	uint32 width = 0;
	uint32 height = 0;
};

#ifdef _DEBUG
bool Renderer::SubmitDebugTextureSource(const Texture2DSourceRgba8& source);
#endif
```

renderer 내부에는 mutex로 보호되는 pending debug texture source를 둔다.

```cpp
#ifdef _DEBUG
std::mutex debugTextureMutex;
Texture2DSourceRgba8 pendingDebugTextureSource;
bool hasPendingDebugTextureSource = false;
Texture2D debugTexture;
#endif
```

render thread는 frame 처리 전 또는 loop 초기에 pending source를 drain해서 backend texture를 생성한다.

```cpp
#ifdef _DEBUG
bool Renderer::DrainDebugTextureSource(RendererHandle rendererHandle);
void Renderer::ReleaseDebugTexture(RendererHandle rendererHandle);
#endif
```

이렇게 하면 `RendererTest.cpp`는 debug fixture/data staging 중심이라는 결정은 유지하면서도, GPU 호출과 handle mutation은 render thread에 묶인다.

## 최종 보정 결론

#2_6의 설계 계약은 유지된다. 단 구현 초안은 다음 네 가지를 반드시 반영해야 한다.

- Profile/Profile2 둘 다 로드하고 하나를 기본 표시, 다른 하나를 교체 fixture로 보관한다.
- `FileSystem::FileExists` + `File::ReadAllBytes`를 함께 사용한다.
- GPU texture 생성/해제와 debug draw handle 설정은 render thread에서만 한다.
- `destroyTexture`를 `destroyRenderer` 전에 호출한다.
