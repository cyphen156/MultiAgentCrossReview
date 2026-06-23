Date: 2026-06-24
Question-ID: Q001
Author: Codex
Responds-To: User decision: Codec belongs under Content, not Core/Resource/Module
Supersedes: Codex/Q001_021_full_2_6_implementation_draft.md
Status: Implementation-Draft
Baseline: 2026-06-23T19:08 sync

# #2_6 implementation draft revision - Content codec layout

## Final location decision

`TextCodec` remains in Core.

The file-format codec dispatcher and JPEG leaf move under `Source/Content`.

```text
Source/Core/Public/TextCodec.h
Source/Core/Private/TextCodec.cpp
    - unchanged
    - text byte <-> CString conversion for Core file I/O

Source/Content/Public/Codec.h
Source/Content/Private/Codec.cpp
    - file-format dispatch facade

Source/Content/Private/JpegCodec.h
Source/Content/Private/JpegCodec.cpp
    - JPEG leaf facade

Source/HAL/Private/PlatformJpegCodec.h
Source/Platform/Windows/Private/PlatformJpegCodec.cpp
    - Windows WIC implementation leaf
```

Reason:

```text
Core      = primitive engine utilities and low-level I/O helpers
Content   = content file bytes -> decoded content source data
Resource  = decoded source data -> runtime resource/cache/handle/lifetime
Renderer  = GPU upload and draw backend
```

## 1. Public Content codec facade

`Source/Content/Public/Codec.h`

```cpp
#pragma once

#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Core/Public/CString.h"

// ============================================================================
// Codec
// ----------------------------------------------------------------------------
// Content file byte buffer를 엔진의 중간 표현으로 변환하는 dispatch facade입니다.
//
// Codec 자체는 특정 파일 포맷 구현체가 아닙니다.
// sourcePath의 확장자/등록 규칙을 보고 적절한 leaf codec으로 위임합니다.
//
// #2_6 범위:
//     - JPG/JPEG image bytes를 canonical RGBA8 image로 변환.
//
// 장기 방향:
//     - TextCodec / JpegCodec / PngCodec / FbxCodec / PackageCodec 같은
//       파일 타입별 leaf codec을 선택하는 상위 dispatch 계층으로 확장합니다.
//
// 비책임:
//     - 파일 I/O.
//     - GPU texture 생성.
//     - Resource lifetime/cache.
//     - 플랫폼 API 직접 호출.
// ============================================================================

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
	static bool DecodeImageRgba8(
		const CString& sourcePath,
		const std::vector<uint8>& bytes,
		DecodedImageRgba8& outImage);

private:
	Codec() = delete;
	~Codec() = delete;

	Codec(const Codec& other) = delete;
	Codec& operator=(const Codec& other) = delete;

	Codec(Codec&& other) = delete;
	Codec& operator=(Codec&& other) = delete;
};
```

## 2. Content dispatcher implementation

`Source/Content/Private/Codec.cpp`

```cpp
#include "pch.h"

#include "Content/Public/Codec.h"

#include "Content/Private/JpegCodec.h"
#include "Core/Public/Path.h"

namespace
{
	bool EqualsIgnoreCaseAscii(const CString& lhs, const CString& rhs)
	{
		if (lhs.length() != rhs.length())
		{
			return false;
		}

		for (CString::size_type i = 0; i < lhs.length(); ++i)
		{
			CChar left = lhs[i];
			CChar right = rhs[i];

			if (left >= CTEXT("A")[0] && left <= CTEXT("Z")[0])
			{
				left = static_cast<CChar>(
					left - CTEXT("A")[0] + CTEXT("a")[0]);
			}

			if (right >= CTEXT("A")[0] && right <= CTEXT("Z")[0])
			{
				right = static_cast<CChar>(
					right - CTEXT("A")[0] + CTEXT("a")[0]);
			}

			if (left != right)
			{
				return false;
			}
		}

		return true;
	}

	bool IsJpegPath(const CString& sourcePath)
	{
		const CString extension = Path::GetExtension(sourcePath);

		return EqualsIgnoreCaseAscii(extension, CTEXT(".jpg")) ||
			EqualsIgnoreCaseAscii(extension, CTEXT(".jpeg"));
	}
}

bool Codec::DecodeImageRgba8(
	const CString& sourcePath,
	const std::vector<uint8>& bytes,
	DecodedImageRgba8& outImage)
{
	outImage = {};

	if (bytes.empty())
	{
		return false;
	}

	if (IsJpegPath(sourcePath))
	{
		return JpegCodec::DecodeToRgba8(bytes, outImage);
	}

	return false;
}
```

## 3. JPEG Content leaf

`Source/Content/Private/JpegCodec.h`

```cpp
#pragma once

#include <vector>

#include "Content/Public/Codec.h"
#include "Core/Public/CPrimitiveTypes.h"

// ============================================================================
// JpegCodec
// ----------------------------------------------------------------------------
// JPEG 파일 포맷 leaf codec facade입니다.
//
// JpegCodec은 JPEG라는 파일 타입의 decode 정책을 소유합니다.
// 현재 #2_6에서는 실제 구현을 플랫폼 leaf에 위임합니다.
//
// 장기적으로 libjpeg-turbo 같은 포터블 전문 decoder를 붙이거나,
// strict JPEG signature validation을 추가할 때 이 계층에서 처리합니다.
// ============================================================================

class JpegCodec final
{
public:
	static bool DecodeToRgba8(
		const std::vector<uint8>& bytes,
		DecodedImageRgba8& outImage);

private:
	JpegCodec() = delete;
	~JpegCodec() = delete;

	JpegCodec(const JpegCodec& other) = delete;
	JpegCodec& operator=(const JpegCodec& other) = delete;

	JpegCodec(JpegCodec&& other) = delete;
	JpegCodec& operator=(JpegCodec&& other) = delete;
};
```

`Source/Content/Private/JpegCodec.cpp`

```cpp
#include "pch.h"

#include "Content/Private/JpegCodec.h"

#include "HAL/Private/PlatformJpegCodec.h"

bool JpegCodec::DecodeToRgba8(
	const std::vector<uint8>& bytes,
	DecodedImageRgba8& outImage)
{
	outImage = {};

	if (bytes.empty())
	{
		return false;
	}

	return PlatformJpegCodec::DecodeToRgba8(bytes, outImage);
}
```

## 4. Platform JPEG leaf

`Source/HAL/Private/PlatformJpegCodec.h`

```cpp
#pragma once

#include <vector>

#include "Content/Public/Codec.h"
#include "Core/Public/CPrimitiveTypes.h"

// ============================================================================
// PlatformJpegCodec
// ----------------------------------------------------------------------------
// JPEG decode의 플랫폼 전용 leaf입니다.
//
// Content Codec / JpegCodec은 WIC, COM, Windows header를 알지 않습니다.
// Windows의 WIC 사용은 이 private HAL 경계 뒤에 격리합니다.
// ============================================================================

class PlatformJpegCodec final
{
private:
	friend class JpegCodec;

	static bool DecodeToRgba8(
		const std::vector<uint8>& bytes,
		DecodedImageRgba8& outImage);

	PlatformJpegCodec() = delete;
	~PlatformJpegCodec() = delete;

	PlatformJpegCodec(const PlatformJpegCodec& other) = delete;
	PlatformJpegCodec& operator=(const PlatformJpegCodec& other) = delete;

	PlatformJpegCodec(PlatformJpegCodec&& other) = delete;
	PlatformJpegCodec& operator=(PlatformJpegCodec&& other) = delete;
};
```

`Source/Platform/Windows/Private/PlatformJpegCodec.cpp`

```cpp
#include "pch.h"

#include "HAL/Private/PlatformJpegCodec.h"

#include <wincodec.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

bool PlatformJpegCodec::DecodeToRgba8(
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

## 5. Call site include change

Renderer test uses Content codec:

```cpp
#include "Content/Public/Codec.h"
```

No `File.cpp` change is required.

`TextCodec` stays in:

```text
Source/Core/Public/TextCodec.h
Source/Core/Private/TextCodec.cpp
```

## 6. Project file manifest

Add:

```text
Source/Content/Public/Codec.h
Source/Content/Private/Codec.cpp
Source/Content/Private/JpegCodec.h
Source/Content/Private/JpegCodec.cpp
Source/HAL/Private/PlatformJpegCodec.h
Source/Platform/Windows/Private/PlatformJpegCodec.cpp
```

Do not rename:

```text
Source/Core/Public/TextCodec.h
Source/Core/Private/TextCodec.cpp
```
