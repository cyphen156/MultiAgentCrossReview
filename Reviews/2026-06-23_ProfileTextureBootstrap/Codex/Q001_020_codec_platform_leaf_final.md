Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User correction: platform code must not be pulled into Core Codec
Supersedes: Codex/Q001_019_codec_leaf_stb_now_turbo_later.md
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 implementation correction - Codec facade with HAL platform leaf

## Final correction

`Codec.cpp` must not include platform code.

The previous "stb now / turbo later" direction is superseded. The user chose
OS-provided decoding for the #2_6 bootstrap, but also rejected pulling WIC into
Core. Therefore the corrected implementation boundary is:

```text
Core/Public/Codec.h
Core/Private/Codec.cpp
    - public codec facade
    - extension / codec-kind dispatch
    - no wincodec.h
    - no COM
    - no _WIN32 helper with platform API calls

HAL/Private/PlatformCodec.h
Platform/Windows/Private/PlatformCodec.cpp
    - private platform leaf
    - WIC implementation
    - Windows-only includes and COM calls
```

This mirrors the existing `File -> PlatformFile` pattern:

```text
File   -> PlatformFile
Codec  -> PlatformCodec
```

## Scope decision

#2_6 uses WIC only as the Windows JPG decode leaf.

This is not a permanent codec architecture decision. Long term, Codec can be
split into a Codec module with format-specific leaves:

```text
CodecModule
    JpegDecoder  -> WIC, libjpeg-turbo, or another selected leaf
    PngDecoder   -> WIC, libpng, or another selected leaf
    FbxDecoder   -> FBX SDK / custom importer / other importer
    PackageCodec -> engine package parser
```

The stable part is the facade and the intermediate CPU data contract. The leaf
implementation can be platform-specific, portable-third-party, or custom,
depending on each format.

## Public Core API

`TextCodec` is still renamed to `Codec`.

`Source/Core/Public/Codec.h`:

```cpp
#pragma once

#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Core/Public/Path.h"

struct DecodedImageRgba8
{
	std::vector<uint8> pixels;
	uint32 width = 0;
	uint32 height = 0;

	bool IsValid() const
	{
		return width > 0 && height > 0 &&
			static_cast<uint64>(pixels.size()) ==
			static_cast<uint64>(width) * height * 4;
	}
};

class Codec final
{
public:
	static bool Decode(const std::vector<uint8>& bytes, std::string& outText);
	static bool Encode(const std::string& text, std::vector<uint8>& outBytes);

	static bool DecodeImageRgba8(
		const Path& sourcePath,
		const std::vector<uint8>& bytes,
		DecodedImageRgba8& outImage);

private:
	Codec() = delete;
	~Codec() = delete;
	Codec(const Codec&) = delete;
	Codec& operator=(const Codec&) = delete;
};
```

`DecodeImageRgba8` is a #2_6 bootstrap image entry. It is not the final general
asset API. ResourceManager later replaces direct caller usage with something
like `LoadTexture2D(path)`.

## Core facade implementation

`Source/Core/Private/Codec.cpp`:

```cpp
#include "pch.h"

#include "Core/Public/Codec.h"

#include "HAL/Private/PlatformCodec.h"

namespace
{
	bool IsJpegExtension(const Path& sourcePath)
	{
		const std::string extension = sourcePath.GetExtensionLower();
		return extension == ".jpg" || extension == ".jpeg";
	}
}

bool Codec::DecodeImageRgba8(
	const Path& sourcePath,
	const std::vector<uint8>& bytes,
	DecodedImageRgba8& outImage)
{
	outImage = {};

	if (bytes.empty())
	{
		return false;
	}

	if (IsJpegExtension(sourcePath))
	{
		return PlatformCodec::DecodeJpegToRgba8(bytes, outImage);
	}

	return false;
}
```

Notes:

- The exact `Path` extension helper name should match the current codebase. If
  `GetExtensionLower()` does not exist, use the existing `Path`/`FileSystem`
  helper and keep this dispatch in Core.
- Core only dispatches by declared path/extension for #2_6. Later strict
  signature/magic validation can be added per leaf if needed.
- No WIC or platform include appears here.

## HAL private leaf

`Source/HAL/Private/PlatformCodec.h`:

```cpp
#pragma once

#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Core/Public/Codec.h"

class PlatformCodec final
{
private:
	friend class Codec;

	static bool DecodeJpegToRgba8(
		const std::vector<uint8>& bytes,
		DecodedImageRgba8& outImage);

	PlatformCodec() = delete;
	~PlatformCodec() = delete;
	PlatformCodec(const PlatformCodec&) = delete;
	PlatformCodec& operator=(const PlatformCodec&) = delete;
};
```

`Source/Platform/Windows/Private/PlatformCodec.cpp`:

```cpp
#include "pch.h"

#include "HAL/Private/PlatformCodec.h"

#include <wincodec.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

bool PlatformCodec::DecodeJpegToRgba8(
	const std::vector<uint8>& bytes,
	DecodedImageRgba8& outImage)
{
	outImage = {};

	if (bytes.empty() || bytes.size() > static_cast<size_t>(DWORD_MAX))
	{
		return false;
	}

	const HRESULT initResult = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
	const bool shouldUninitialize = SUCCEEDED(initResult);

	bool success = false;

	{
		ComPtr<IWICImagingFactory> factory;
		ComPtr<IWICStream> stream;
		ComPtr<IWICBitmapDecoder> decoder;
		ComPtr<IWICBitmapFrameDecode> frame;
		ComPtr<IWICFormatConverter> converter;

		HRESULT hr = CoCreateInstance(
			CLSID_WICImagingFactory,
			nullptr,
			CLSCTX_INPROC_SERVER,
			IID_PPV_ARGS(factory.GetAddressOf()));

		if (SUCCEEDED(hr))
		{
			hr = factory->CreateStream(stream.GetAddressOf());
		}

		if (SUCCEEDED(hr))
		{
			hr = stream->InitializeFromMemory(
				const_cast<BYTE*>(bytes.data()),
				static_cast<DWORD>(bytes.size()));
		}

		if (SUCCEEDED(hr))
		{
			hr = factory->CreateDecoderFromStream(
				stream.Get(),
				nullptr,
				WICDecodeMetadataCacheOnDemand,
				decoder.GetAddressOf());
		}

		if (SUCCEEDED(hr))
		{
			hr = decoder->GetFrame(0, frame.GetAddressOf());
		}

		if (SUCCEEDED(hr))
		{
			hr = factory->CreateFormatConverter(converter.GetAddressOf());
		}

		if (SUCCEEDED(hr))
		{
			hr = converter->Initialize(
				frame.Get(),
				GUID_WICPixelFormat32bppRGBA,
				WICBitmapDitherTypeNone,
				nullptr,
				0.0,
				WICBitmapPaletteTypeCustom);
		}

		UINT width = 0;
		UINT height = 0;

		if (SUCCEEDED(hr))
		{
			hr = converter->GetSize(&width, &height);
		}

		if (SUCCEEDED(hr) && width > 0 && height > 0)
		{
			const uint64 byteCount =
				static_cast<uint64>(width) *
				static_cast<uint64>(height) *
				4;

			if (byteCount <= static_cast<uint64>(UINT_MAX))
			{
				const UINT stride = width * 4;
				outImage.pixels.resize(static_cast<size_t>(byteCount));

				hr = converter->CopyPixels(
					nullptr,
					stride,
					static_cast<UINT>(byteCount),
					outImage.pixels.data());

				if (SUCCEEDED(hr))
				{
					outImage.width = width;
					outImage.height = height;
					success = outImage.IsValid();
				}
			}
		}
	}

	if (shouldUninitialize)
	{
		CoUninitialize();
	}

	if (success == false)
	{
		outImage = {};
	}

	return success;
}
```

## Integration manifest correction

Rename:

```text
Source/Core/Public/TextCodec.h  -> Source/Core/Public/Codec.h
Source/Core/Private/TextCodec.cpp -> Source/Core/Private/Codec.cpp
```

Add:

```text
Source/HAL/Private/PlatformCodec.h
Source/Platform/Windows/Private/PlatformCodec.cpp
```

Modify:

```text
Source/Core/Private/File.cpp
Source/Test/Renderer/RendererTest.cpp
CyphenEngine.vcxproj
```

Do not add:

```text
Source/Core/Private/ImageCodec.cpp
Source/Platform/Windows/Private/PlatformImageDecoder.cpp
ThirdParty/stb/stb_image.h
libjpeg-turbo dependency
```

## Final contract

```text
FileSystem / File
    -> bytes

Codec::DecodeImageRgba8
    -> extension dispatch
    -> PlatformCodec::DecodeJpegToRgba8
    -> DecodedImageRgba8

RendererTest
    -> SubmitDebugTextureSource

Renderer render thread
    -> createTextureRgba8
    -> DrawTexturedQuad(handle)
```

The platform code is not in Core. It is a HAL private leaf. That is the
correct #2_6 compromise for OS-provided WIC now and future format-specific
codec specialization later.
