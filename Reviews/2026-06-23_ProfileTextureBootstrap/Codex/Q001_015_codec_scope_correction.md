Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User codec scope correction
Supersedes: none
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 구현 보정 - ImageCodec 파일 폐기와 TextCodec 임시 승격

## 사용자 결정

`ImageCodec.h/.cpp` 신규 파일은 만들지 않는다. 현재 `TextCodec`은 장기적으로 범용 `Codec`으로 승격될 예정이므로, #2_6의 이미지 decode 최소 구현은 `TextCodec` 내부에 둔다.

## 수정된 구현 기준

- 신규 `ImageCodec.*` 파일 없음.
- `TextCodec.h/.cpp`에 `DecodedImageRgba8`와 이미지 decode entry를 추가한다.
- 함수 이름은 기존 text `Decode`와 충돌하지 않도록 `DecodeImageRgba8`로 둔다.
- `sourcePath`를 받아 `Path::GetExtension` 기준으로 `.jpg/.jpeg`만 허용한다.
- #2_6에서는 registry를 만들지 않고, 확장자 기반 하드코딩 dispatch만 둔다.
- 나중에 `TextCodec -> Codec` 승격 시 같은 함수/구조를 `Codec`으로 옮긴다.

## 제안 시그니처

```cpp
struct DecodedImageRgba8
{
	std::vector<uint8> pixels;
	uint32 width = 0;
	uint32 height = 0;

	bool IsValid() const;
};

class TextCodec final
{
public:
	static bool DecodeImageRgba8(
		const CString& sourcePath,
		const std::vector<uint8>& bytes,
		DecodedImageRgba8& outImage);
};
```

## 책임 경계

`File` / `FileSystem`은 여전히 I/O만 담당한다. `TextCodec::DecodeImageRgba8`는 `sourcePath`의 확장자를 보고 엔진이 약속한 codec 처리를 수행한다.

```text
FileSystem::FileExists
File::ReadAllBytes
TextCodec::DecodeImageRgba8(path, bytes)
Renderer::SubmitDebugTextureSource(decodedImage)
```

## 주의

이 결정은 `ImageCodec` 파일 분리를 하지 않는다는 뜻이지, Renderer/backend가 JPG를 decode한다는 뜻이 아니다. Renderer ABI에는 여전히 decoded RGBA8만 넘어간다.
