Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User codec rename confirmation
Supersedes: Codex/Q001_015_codec_scope_correction.md
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 구현 보정 - TextCodec을 Codec으로 승격 확정

## 사용자 확정

`TextCodec` 유지가 아니라 `Codec` 리네임/승격으로 확정한다.

## 수정된 구현 기준

- 신규 `ImageCodec.*` 파일은 만들지 않는다.
- 기존 `TextCodec.h/.cpp`는 `Codec.h/.cpp`로 리네임한다.
- 기존 text API는 `Codec::Encode`, `Codec::Decode`로 유지한다.
- 신규 image API는 `Codec::DecodeImageRgba8`로 추가한다.
- `File.cpp`의 기존 `TextCodec::Decode/Encode` 호출은 `Codec::Decode/Encode`로 바꾼다.
- `PlatformImageDecoder.h`는 `friend class Codec`이며 `Core/Public/Codec.h`를 include한다.
- `PlatformImageDecoder.cpp`는 WIC leaf로 두고 Core 공개 표면에는 WIC를 노출하지 않는다.

## 최종 codec 흐름

```text
FileSystem::FileExists
File::ReadAllBytes
Codec::DecodeImageRgba8(path, bytes, decodedImage)
Renderer::SubmitDebugTextureSource(decodedImage)
```

장기적으로 ResourceManager가 들어오면 `Codec::DecodeImageRgba8` 직접 호출은 RM 내부로 들어간다.

## 매니페스트 보정

삭제/리네임:

```text
Core/Public/TextCodec.h -> Core/Public/Codec.h
Core/Private/TextCodec.cpp -> Core/Private/Codec.cpp
```

수정:

```text
Core/Private/File.cpp
CyphenEngine.vcxproj
기존 TextCodec include/call site
```

신규:

```text
HAL/Private/PlatformImageDecoder.h
Platform/Windows/Private/PlatformImageDecoder.cpp
```
