Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User resource-manager direction correction
Supersedes: none
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 구현 보정 - Codec 직접 호출은 임시 경로

## 사용자 결정

#2_6에서는 `RendererTest.cpp`가 `TextCodec::DecodeImageRgba8`를 직접 호출할 수밖에 없지만, 장기적으로 codec 직접 호출은 제거된다. ResourceManager 같은 상위 계층이 `Path` 또는 file name을 받아 파일 읽기, codec 선택, decode, texture/resource 생성을 자동으로 수행하는 형태로 분화한다.

## 장기 방향

범용 엔진의 실사용 API는 사용자가 codec을 직접 고르는 형태가 아니다.

장기 목표:

```text
ResourceManager::LoadTexture(path)
    -> FileSystem/File
    -> Codec dispatch
    -> DecodedImageRgba8
    -> Renderer texture upload
    -> TextureHandle / TextureResource
```

호출자는 다음처럼 사용한다.

```text
TextureHandle profile = ResourceManager::LoadTexture("Resources/Thumbnail/Profile.jpg");
```

호출자는 `.jpg`를 어떤 decoder가 처리하는지, RGBA8로 정규화되는지, GPU upload가 어느 backend API로 가는지 직접 알지 않는다.

## #2_6에서의 의미

`RendererTest.cpp`의 직접 호출은 ResourceManager가 아직 없기 때문에 생긴 debug fixture 경로다.

```text
RendererTest.cpp
    FileSystem::FileExists
    File::ReadAllBytes
    TextCodec::DecodeImageRgba8
    Renderer::SubmitDebugTextureSource
```

이 코드는 최종 runtime API가 아니라, 이후 ResourceManager가 들어올 때 다음으로 대체될 임시 fixture다.

```text
RendererTest.cpp
    ResourceManager::LoadTexture or LoadDecodedTextureFixture
```

## 구현상 주의

- #2_6에서 codec 직접 호출을 public gameplay/runtime 사용 패턴처럼 설명하지 않는다.
- `TextCodec::DecodeImageRgba8`는 ResourceManager가 생기기 전까지의 하위 계층 함수다.
- `RendererTest.cpp`는 임시로 File/Codec을 조립하지만, 실제 장기 조립 책임은 ResourceManager로 이동한다.
