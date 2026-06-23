Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User request: show full #2_6 implementation code
Supersedes: none
Status: Implementation-Draft
Baseline: 2026-06-23T19:08 sync

# #2_6 full implementation draft

This is a code draft for the original project. The mirror is not edited.

Final boundaries:

- `Codec` is the public Core facade.
- WIC is not included in Core.
- WIC lives behind `HAL/Private/PlatformCodec.h` and
  `Platform/Windows/Private/PlatformCodec.cpp`.
- `RendererTest` loads/decode CPU image data only.
- GPU texture creation/destruction happens on the render thread.

## 1. Rename TextCodec to Codec

Rename files:

```text
Source/Core/Public/TextCodec.h  -> Source/Core/Public/Codec.h
Source/Core/Private/TextCodec.cpp -> Source/Core/Private/Codec.cpp
```

`Source/Core/Public/Codec.h`

```cpp
#pragma once

#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Core/Public/CString.h"
#include "Core/Public/FileTypes.h"

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
	static bool Encode(
		const CString& text,
		std::vector<uint8>& outBytes,
		TextEncoding encoding,
		LineEnding lineEnding);

	static bool Decode(
		const std::vector<uint8>& bytes,
		CString& outText,
		TextEncoding encoding);

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

`Source/Core/Private/Codec.cpp`

```cpp
#include "pch.h"

#include <vector>

#include "Core/Public/Codec.h"
#include "Core/Public/Path.h"
#include "HAL/Private/PlatformCodec.h"

namespace
{
	// Keep the existing TextCodec.cpp helper functions unchanged:
	// IsHighSurrogate, IsLowSurrogate, IsValidCodePoint,
	// AppendCodePointToCString, DecodeUtf8CodePoint, ReadUint16,
	// WriteUint16, DecodeUtf16CodePoint, AppendCodePointAsUtf8Bytes,
	// AppendCodePointAsUtf16Bytes, AppendCodePointAsAnsiByte,
	// AppendCodePointAsEncodedBytes, ReadNextCodePointFromCString,
	// AppendLineEnding, DecodeUtf8, DecodeUtf16, DecodeAnsi.
	//
	// Only rename TextCodec::Encode/Decode definitions to Codec::Encode/Decode.

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

bool Codec::Encode(
	const CString& text,
	std::vector<uint8>& outBytes,
	TextEncoding encoding,
	LineEnding lineEnding)
{
	// Existing TextCodec::Encode body, unchanged except the class name.
}

bool Codec::Decode(
	const std::vector<uint8>& bytes,
	CString& outText,
	TextEncoding encoding)
{
	// Existing TextCodec::Decode body, unchanged except the class name.
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
		return PlatformCodec::DecodeJpegToRgba8(bytes, outImage);
	}

	return false;
}
```

`Source/Core/Private/File.cpp`

```cpp
// replace include
#include "Core/Public/Codec.h"

// replace calls
Codec::Decode(bytes, outText, encoding);
Codec::Encode(text, bytes, encoding, lineEnding);
```

## 2. HAL platform codec leaf

`Source/HAL/Private/PlatformCodec.h`

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

	PlatformCodec(const PlatformCodec& other) = delete;
	PlatformCodec& operator=(const PlatformCodec& other) = delete;

	PlatformCodec(PlatformCodec&& other) = delete;
	PlatformCodec& operator=(PlatformCodec&& other) = delete;
};
```

`Source/Platform/Windows/Private/PlatformCodec.cpp`

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

## 3. Renderer ABI and command stream

`Source/Modules/Renderer/Public/RendererTypes.h`

```cpp
using RendererHandle = void*;
using RendererTextureHandle = void*;

struct Texture2D
{
	RendererTextureHandle handle = nullptr;
	uint32 width = 0;
	uint32 height = 0;

	bool IsValid() const
	{
		return handle != nullptr && width > 0 && height > 0;
	}
};
```

`Source/Modules/Renderer/Public/RendererModule.h`

```cpp
constexpr uint32 RENDERER_MODULE_ABI_GENERATION = 5;
constexpr uint32 RENDERER_MODULE_API_VERSION = RENDERER_MODULE_ABI_GENERATION;

using CreateTextureRgba8Function =
	RendererModuleResult(*)(
		RendererHandle rendererHandle,
		const uint8* rgbaPixels,
		uint64 byteCount,
		uint32 width,
		uint32 height,
		RendererTextureHandle* outTextureHandle);

using DestroyTextureFunction =
	void(*)(
		RendererHandle rendererHandle,
		RendererTextureHandle textureHandle);

struct RendererModuleApi
{
	uint32 apiVersion = 0;
	RendererType rendererType = RendererType::None;

	CreateRendererFunction createRenderer = nullptr;
	DestroyRendererFunction destroyRenderer = nullptr;
	ExecuteCommandListFunction executeCommandList = nullptr;
	CreateTextureRgba8Function createTextureRgba8 = nullptr;
	DestroyTextureFunction destroyTexture = nullptr;
};

static_assert(sizeof(RendererModuleApi) == 48, "RendererModuleApi must be 48 bytes on x64.");
```

`Source/Modules/Renderer/Public/RenderCommand.h`

```cpp
#include "Modules/Renderer/Public/RendererTypes.h"

enum class RenderCommandType : uint32
{
	None = 0,
	ClearRenderTarget = 1,
	Present = 2,
	DrawTexturedQuad = 3
};

struct DrawTexturedQuadCommand
{
	RendererTextureHandle textureHandle = nullptr;
};

static_assert(sizeof(DrawTexturedQuadCommand) == 8, "DrawTexturedQuadCommand must be 8 bytes.");
```

`Source/Modules/Renderer/Private/RenderCommandBuffer.h`

```cpp
bool AppendDrawTexturedQuad(RendererTextureHandle textureHandle);
```

`Source/Modules/Renderer/Private/RenderCommandBuffer.cpp`

```cpp
bool RenderCommandBuffer::AppendDrawTexturedQuad(RendererTextureHandle textureHandle)
{
	if (textureHandle == nullptr)
	{
		return false;
	}

	DrawTexturedQuadCommand command = {};
	command.textureHandle = textureHandle;

	return commandBuffer.AppendCommand(
		static_cast<uint32>(RenderCommandType::DrawTexturedQuad),
		&command,
		static_cast<uint32>(sizeof(command)));
}
```

## 4. Engine renderer wiring

`Source/Modules/Renderer/Public/Renderer.h`

```cpp
#include "Core/Public/Codec.h"

public:
#ifdef _DEBUG
	bool SubmitDebugTextureSource(DecodedImageRgba8 source);
#endif

private:
#ifdef _DEBUG
	bool DrainDebugTextureSource(RendererHandle rendererHandle);
	void ReleaseDebugTexture(RendererHandle rendererHandle);
#endif

private:
#ifdef _DEBUG
	std::mutex debugTextureMutex;
	DecodedImageRgba8 pendingDebugTextureSource;
	bool hasPendingDebugTextureSource = false;
	Texture2D debugTexture;
#endif
```

`Source/Modules/Renderer/Private/Renderer.cpp`

```cpp
// Initialize validation adds ABI 5 functions.
if (resolvedModuleApi.rendererType == RendererType::None ||
	resolvedModuleApi.createRenderer == nullptr ||
	resolvedModuleApi.destroyRenderer == nullptr ||
	resolvedModuleApi.executeCommandList == nullptr ||
	resolvedModuleApi.createTextureRgba8 == nullptr ||
	resolvedModuleApi.destroyTexture == nullptr)
{
	ReleaseModule();
	return false;
}
```

```cpp
// Run loop, before BuildRenderCommandList.
while (AcquireFrame(currentFrame))
{
#ifdef _DEBUG
	if (DrainDebugTextureSource(rendererHandle) == false)
	{
		StopFrameInput();
		SetThreadState(RendererThreadState::Failed);
		threadCondition.notify_all();
		break;
	}
#endif

	if (BuildRenderCommandList(currentFrame, commandBuffer) == false)
	{
		StopFrameInput();
		SetThreadState(RendererThreadState::Failed);
		threadCondition.notify_all();
		break;
	}

	if (ExecuteRenderCommandList(rendererHandle, commandBuffer) == false)
	{
		StopFrameInput();
		SetThreadState(RendererThreadState::Failed);
		threadCondition.notify_all();
		break;
	}
}

#ifdef _DEBUG
ReleaseDebugTexture(rendererHandle);
#endif

moduleApi.destroyRenderer(rendererHandle);
```

```cpp
// BuildRenderCommandList, after clear and before present.
#ifdef _DEBUG
if (debugTexture.IsValid())
{
	if (outCommandBuffer.AppendDrawTexturedQuad(debugTexture.handle) == false)
	{
		return false;
	}
}
#endif
```

```cpp
#ifdef _DEBUG
bool Renderer::SubmitDebugTextureSource(DecodedImageRgba8 source)
{
	if (source.IsValid() == false)
	{
		return false;
	}

	std::lock_guard<std::mutex> lock(debugTextureMutex);
	pendingDebugTextureSource = std::move(source);
	hasPendingDebugTextureSource = true;

	return true;
}

bool Renderer::DrainDebugTextureSource(RendererHandle rendererHandle)
{
	DecodedImageRgba8 source;

	{
		std::lock_guard<std::mutex> lock(debugTextureMutex);

		if (hasPendingDebugTextureSource == false)
		{
			return true;
		}

		source = std::move(pendingDebugTextureSource);
		pendingDebugTextureSource = {};
		hasPendingDebugTextureSource = false;
	}

	if (debugTexture.IsValid())
	{
		moduleApi.destroyTexture(rendererHandle, debugTexture.handle);
		debugTexture = {};
	}

	RendererTextureHandle textureHandle = nullptr;

	if (moduleApi.createTextureRgba8(
		rendererHandle,
		source.pixels.data(),
		static_cast<uint64>(source.pixels.size()),
		source.width,
		source.height,
		&textureHandle) != RendererModuleResult::Success ||
		textureHandle == nullptr)
	{
		return false;
	}

	debugTexture.handle = textureHandle;
	debugTexture.width = source.width;
	debugTexture.height = source.height;

	return true;
}

void Renderer::ReleaseDebugTexture(RendererHandle rendererHandle)
{
	if (debugTexture.IsValid())
	{
		moduleApi.destroyTexture(rendererHandle, debugTexture.handle);
		debugTexture = {};
	}
}
#endif
```

## 5. CyphenEngine forwarding

`Source/Engine/Public/CyphenEngine.h`

```cpp
#include "Core/Public/Codec.h"

public:
#ifdef _DEBUG
	bool SubmitDebugTextureSource(DecodedImageRgba8 source);
#endif
```

`Source/Engine/Private/CyphenEngine.cpp`

```cpp
#ifdef _DEBUG
bool CyphenEngine::SubmitDebugTextureSource(DecodedImageRgba8 source)
{
	return renderer.SubmitDebugTextureSource(std::move(source));
}
#endif
```

Also replace direct debug output in `CyphenEngine::Run`:

```cpp
Logger::WriteLine(CTEXT("[Renderer] BeginRenderingFrame failed."));
```

and use the shared test/debug sink or `Logger` for the frame diagnostic. Do not
call `OutputDebugStringA` directly from `CyphenEngine.cpp`.

## 6. Renderer test fixture

`Source/Test/Common/TestHarness.h`

```cpp
#pragma once

#include "Core/Public/CPrimitiveTypes.h"

struct TestContext
{
	int32 passCount = 0;
	int32 failCount = 0;
};

void WriteTestLine(const char* message);
void WriteTestLineWithNewLine(const char* message);
void Expect(TestContext& context, bool condition, const char* name);
void WriteTestSummary(const char* testName, const TestContext& context);
```

`Source/Test/Common/TestHarness.cpp`

```cpp
#include "pch.h"

#include <cstdio>

#include "Test/Common/TestHarness.h"

void WriteTestLine(const char* message)
{
#if PLATFORM_WINDOWS
	OutputDebugStringA(message);
#endif
}

void WriteTestLineWithNewLine(const char* message)
{
#if PLATFORM_WINDOWS
	OutputDebugStringA(message);
	OutputDebugStringA("\n");
#endif
}

void Expect(TestContext& context, bool condition, const char* name)
{
	if (condition)
	{
		++context.passCount;
		WriteTestLine("[PASS] ");
	}
	else
	{
		++context.failCount;
		WriteTestLine("[FAIL] ");
	}

	WriteTestLineWithNewLine(name);
}

void WriteTestSummary(const char* testName, const TestContext& context)
{
	char summary[128] = {};
	std::snprintf(
		summary,
		sizeof(summary),
		"[%s] Summary PASS=%d FAIL=%d",
		testName,
		context.passCount,
		context.failCount);

	WriteTestLineWithNewLine(summary);
}
```

`Source/Test/Renderer/RendererTest.h`

```cpp
#pragma once

class CyphenEngine;

void RunRendererTests(CyphenEngine& engine);
```

`Source/Test/Renderer/RendererTest.cpp`

```cpp
#include "pch.h"

#include <vector>

#include "Core/Public/Codec.h"
#include "Core/Public/File.h"
#include "Core/Public/FileSystem.h"
#include "Engine/Public/CyphenEngine.h"
#include "Test/Common/TestHarness.h"
#include "Test/Renderer/RendererTest.h"

namespace
{
	bool LoadDecodedImageRgba8(
		const CString& path,
		DecodedImageRgba8& outImage)
	{
		outImage = {};

		if (FileSystem::FileExists(path) == false)
		{
			return false;
		}

		std::vector<uint8> bytes;

		if (File::ReadAllBytes(path, bytes) == false)
		{
			return false;
		}

		return Codec::DecodeImageRgba8(path, bytes, outImage);
	}
}

void RunRendererTests(CyphenEngine& engine)
{
	TestContext context;

	WriteTestLineWithNewLine("[RendererTests] Begin");

	DecodedImageRgba8 profile;
	DecodedImageRgba8 profile2;

	const bool profileLoaded = LoadDecodedImageRgba8(
		CTEXT("Resources/Thumbnail/Profile.jpg"),
		profile);

	Expect(context, profileLoaded && profile.IsValid(),
		"RendererTests loads Profile.jpg as RGBA8");

	const bool profile2Loaded = LoadDecodedImageRgba8(
		CTEXT("Resources/Thumbnail/Profile2.jpg"),
		profile2);

	Expect(context, profile2Loaded && profile2.IsValid(),
		"RendererTests loads Profile2.jpg as RGBA8");

	if (profileLoaded && profile.IsValid())
	{
		Expect(context, engine.SubmitDebugTextureSource(std::move(profile)),
			"RendererTests submits Profile.jpg debug texture source");
	}

	WriteTestSummary("RendererTests", context);
	WriteTestLineWithNewLine("[RendererTests] End");
}
```

`Source/Platform/Windows/Private/Launch.cpp`

```cpp
#ifdef _DEBUG
#include "Test/CoreIo/CoreIoTests.h"
#include "Test/Module/ModuleTest.h"
#include "Test/Renderer/RendererTest.h"
#endif
```

```cpp
#ifdef _DEBUG
RunModuleTests();
RunRendererTests(Launch::engineInstance);
#endif
```

## 7. DX11 backend

`Modules/Renderer/CyphenRendererDx11/Source/Private/Dx11Renderer.h`

```cpp
#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>

struct Dx11Texture
{
	Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> shaderResourceView;
	uint32 width = 0;
	uint32 height = 0;
};

class Dx11Renderer final
{
public:
	bool CreateTextureRgba8(
		const uint8* rgbaPixels,
		uint64 byteCount,
		uint32 width,
		uint32 height,
		RendererTextureHandle* outTextureHandle);

	void DestroyTexture(RendererTextureHandle textureHandle);

private:
	bool EnsureTexturedQuadResources();
	void ReleaseTexturedQuadResources();
	bool ExecuteDrawTexturedQuad(const RenderCommandWord* payloadWords, uint32 payloadWordCount);

private:
	uint32 viewportWidth = 0;
	uint32 viewportHeight = 0;

	Microsoft::WRL::ComPtr<ID3D11VertexShader> texturedQuadVertexShader;
	Microsoft::WRL::ComPtr<ID3D11PixelShader> texturedQuadPixelShader;
	Microsoft::WRL::ComPtr<ID3D11InputLayout> texturedQuadInputLayout;
	Microsoft::WRL::ComPtr<ID3D11Buffer> texturedQuadVertexBuffer;
	Microsoft::WRL::ComPtr<ID3D11Buffer> texturedQuadIndexBuffer;
	Microsoft::WRL::ComPtr<ID3D11SamplerState> texturedQuadSampler;
	bool texturedQuadResourcesReady = false;
};
```

`Modules/Renderer/CyphenRendererDx11/Source/Private/Dx11Renderer.cpp`

```cpp
#include "Dx11Renderer.h"

#include <cstring>
#include <new>

#include <d3dcompiler.h>

#pragma comment(lib, "d3dcompiler.lib")

using Microsoft::WRL::ComPtr;

namespace
{
	struct TexturedQuadVertex
	{
		float x;
		float y;
		float z;
		float u;
		float v;
	};

	constexpr char TexturedQuadShaderSource[] =
		"struct VSInput { float3 position : POSITION; float2 uv : TEXCOORD0; };"
		"struct VSOutput { float4 position : SV_POSITION; float2 uv : TEXCOORD0; };"
		"VSOutput VsMain(VSInput input) {"
		"    VSOutput output;"
		"    output.position = float4(input.position, 1.0);"
		"    output.uv = input.uv;"
		"    return output;"
		"}"
		"Texture2D ProfileTexture : register(t0);"
		"SamplerState ProfileSampler : register(s0);"
		"float4 PsMain(VSOutput input) : SV_TARGET {"
		"    return ProfileTexture.Sample(ProfileSampler, input.uv);"
		"}";
}
```

Inside `Initialize`, after successful device creation:

```cpp
viewportWidth = windowInfo.windowWidth;
viewportHeight = windowInfo.windowHeight;
```

Inside `Shutdown`, before `renderTargetView.Reset()`:

```cpp
ReleaseTexturedQuadResources();
```

Inside `ExecuteCommandList` switch:

```cpp
case RenderCommandType::DrawTexturedQuad:
	if (ExecuteDrawTexturedQuad(payloadWords, header.payloadWordCount) == false)
	{
		return false;
	}
	break;
```

Texture upload:

```cpp
bool Dx11Renderer::CreateTextureRgba8(
	const uint8* rgbaPixels,
	uint64 byteCount,
	uint32 width,
	uint32 height,
	RendererTextureHandle* outTextureHandle)
{
	if (rgbaPixels == nullptr ||
		outTextureHandle == nullptr ||
		*outTextureHandle != nullptr ||
		width == 0 ||
		height == 0 ||
		device == nullptr)
	{
		return false;
	}

	const uint64 expectedByteCount =
		static_cast<uint64>(width) *
		static_cast<uint64>(height) *
		4;

	if (byteCount != expectedByteCount ||
		expectedByteCount > static_cast<uint64>(UINT_MAX))
	{
		return false;
	}

	Dx11Texture* texture = new (std::nothrow) Dx11Texture();

	if (texture == nullptr)
	{
		return false;
	}

	D3D11_TEXTURE2D_DESC textureDesc = {};
	textureDesc.Width = width;
	textureDesc.Height = height;
	textureDesc.MipLevels = 1;
	textureDesc.ArraySize = 1;
	textureDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	textureDesc.SampleDesc.Count = 1;
	textureDesc.Usage = D3D11_USAGE_IMMUTABLE;
	textureDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;

	D3D11_SUBRESOURCE_DATA initialData = {};
	initialData.pSysMem = rgbaPixels;
	initialData.SysMemPitch = width * 4;

	HRESULT result = device->CreateTexture2D(
		&textureDesc,
		&initialData,
		texture->texture.GetAddressOf());

	if (FAILED(result))
	{
		delete texture;
		return false;
	}

	D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
	srvDesc.Format = textureDesc.Format;
	srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	srvDesc.Texture2D.MipLevels = 1;

	result = device->CreateShaderResourceView(
		texture->texture.Get(),
		&srvDesc,
		texture->shaderResourceView.GetAddressOf());

	if (FAILED(result))
	{
		delete texture;
		return false;
	}

	texture->width = width;
	texture->height = height;
	*outTextureHandle = texture;

	return true;
}

void Dx11Renderer::DestroyTexture(RendererTextureHandle textureHandle)
{
	Dx11Texture* texture = static_cast<Dx11Texture*>(textureHandle);

	if (texture == nullptr)
	{
		return;
	}

	if (deviceContext != nullptr)
	{
		ID3D11ShaderResourceView* nullSrv = nullptr;
		deviceContext->PSSetShaderResources(0, 1, &nullSrv);
	}

	delete texture;
}
```

Quad resources:

```cpp
bool Dx11Renderer::EnsureTexturedQuadResources()
{
	if (texturedQuadResourcesReady)
	{
		return true;
	}

	if (device == nullptr)
	{
		return false;
	}

	ComPtr<ID3DBlob> vertexShaderBlob;
	ComPtr<ID3DBlob> pixelShaderBlob;
	ComPtr<ID3DBlob> errorBlob;

	HRESULT result = D3DCompile(
		TexturedQuadShaderSource,
		sizeof(TexturedQuadShaderSource) - 1,
		nullptr,
		nullptr,
		nullptr,
		"VsMain",
		"vs_4_0",
		0,
		0,
		vertexShaderBlob.GetAddressOf(),
		errorBlob.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	result = D3DCompile(
		TexturedQuadShaderSource,
		sizeof(TexturedQuadShaderSource) - 1,
		nullptr,
		nullptr,
		nullptr,
		"PsMain",
		"ps_4_0",
		0,
		0,
		pixelShaderBlob.GetAddressOf(),
		errorBlob.ReleaseAndGetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	result = device->CreateVertexShader(
		vertexShaderBlob->GetBufferPointer(),
		vertexShaderBlob->GetBufferSize(),
		nullptr,
		texturedQuadVertexShader.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	result = device->CreatePixelShader(
		pixelShaderBlob->GetBufferPointer(),
		pixelShaderBlob->GetBufferSize(),
		nullptr,
		texturedQuadPixelShader.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	const D3D11_INPUT_ELEMENT_DESC inputElements[] =
	{
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 }
	};

	result = device->CreateInputLayout(
		inputElements,
		static_cast<UINT>(sizeof(inputElements) / sizeof(inputElements[0])),
		vertexShaderBlob->GetBufferPointer(),
		vertexShaderBlob->GetBufferSize(),
		texturedQuadInputLayout.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	const TexturedQuadVertex vertices[] =
	{
		{ -1.0f,  1.0f, 0.0f, 0.0f, 0.0f },
		{  1.0f,  1.0f, 0.0f, 1.0f, 0.0f },
		{  1.0f, -1.0f, 0.0f, 1.0f, 1.0f },
		{ -1.0f, -1.0f, 0.0f, 0.0f, 1.0f }
	};

	D3D11_BUFFER_DESC vertexBufferDesc = {};
	vertexBufferDesc.ByteWidth = static_cast<UINT>(sizeof(vertices));
	vertexBufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
	vertexBufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;

	D3D11_SUBRESOURCE_DATA vertexData = {};
	vertexData.pSysMem = vertices;

	result = device->CreateBuffer(
		&vertexBufferDesc,
		&vertexData,
		texturedQuadVertexBuffer.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	const uint16 indices[] =
	{
		0, 1, 2,
		0, 2, 3
	};

	D3D11_BUFFER_DESC indexBufferDesc = {};
	indexBufferDesc.ByteWidth = static_cast<UINT>(sizeof(indices));
	indexBufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
	indexBufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;

	D3D11_SUBRESOURCE_DATA indexData = {};
	indexData.pSysMem = indices;

	result = device->CreateBuffer(
		&indexBufferDesc,
		&indexData,
		texturedQuadIndexBuffer.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	D3D11_SAMPLER_DESC samplerDesc = {};
	samplerDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
	samplerDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
	samplerDesc.MaxLOD = D3D11_FLOAT32_MAX;

	result = device->CreateSamplerState(
		&samplerDesc,
		texturedQuadSampler.GetAddressOf());

	if (FAILED(result))
	{
		ReleaseTexturedQuadResources();
		return false;
	}

	texturedQuadResourcesReady = true;
	return true;
}

void Dx11Renderer::ReleaseTexturedQuadResources()
{
	texturedQuadSampler.Reset();
	texturedQuadIndexBuffer.Reset();
	texturedQuadVertexBuffer.Reset();
	texturedQuadInputLayout.Reset();
	texturedQuadPixelShader.Reset();
	texturedQuadVertexShader.Reset();
	texturedQuadResourcesReady = false;
}
```

Draw command:

```cpp
bool Dx11Renderer::ExecuteDrawTexturedQuad(
	const RenderCommandWord* payloadWords,
	uint32 payloadWordCount)
{
	if (payloadWords == nullptr ||
		payloadWordCount != 1 ||
		deviceContext == nullptr ||
		renderTargetView == nullptr ||
		viewportWidth == 0 ||
		viewportHeight == 0)
	{
		return false;
	}

	DrawTexturedQuadCommand command = {};
	std::memcpy(&command, payloadWords, sizeof(command));

	Dx11Texture* texture = static_cast<Dx11Texture*>(command.textureHandle);

	if (texture == nullptr || texture->shaderResourceView == nullptr)
	{
		return false;
	}

	if (EnsureTexturedQuadResources() == false)
	{
		return false;
	}

	D3D11_VIEWPORT viewport = {};
	viewport.TopLeftX = 0.0f;
	viewport.TopLeftY = 0.0f;
	viewport.Width = static_cast<float>(viewportWidth);
	viewport.Height = static_cast<float>(viewportHeight);
	viewport.MinDepth = 0.0f;
	viewport.MaxDepth = 1.0f;

	const UINT stride = sizeof(TexturedQuadVertex);
	const UINT offset = 0;

	ID3D11Buffer* vertexBuffers[] =
	{
		texturedQuadVertexBuffer.Get()
	};

	ID3D11ShaderResourceView* srvs[] =
	{
		texture->shaderResourceView.Get()
	};

	ID3D11SamplerState* samplers[] =
	{
		texturedQuadSampler.Get()
	};

	deviceContext->OMSetRenderTargets(1, renderTargetView.GetAddressOf(), nullptr);
	deviceContext->RSSetViewports(1, &viewport);
	deviceContext->IASetInputLayout(texturedQuadInputLayout.Get());
	deviceContext->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
	deviceContext->IASetVertexBuffers(0, 1, vertexBuffers, &stride, &offset);
	deviceContext->IASetIndexBuffer(texturedQuadIndexBuffer.Get(), DXGI_FORMAT_R16_UINT, 0);
	deviceContext->VSSetShader(texturedQuadVertexShader.Get(), nullptr, 0);
	deviceContext->PSSetShader(texturedQuadPixelShader.Get(), nullptr, 0);
	deviceContext->PSSetShaderResources(0, 1, srvs);
	deviceContext->PSSetSamplers(0, 1, samplers);
	deviceContext->DrawIndexed(6, 0, 0);

	return true;
}
```

`Modules/Renderer/CyphenRendererDx11/Source/Private/Dx11RendererModule.cpp`

```cpp
RendererModuleResult CreateTextureRgba8(
	RendererHandle rendererHandle,
	const uint8* rgbaPixels,
	uint64 byteCount,
	uint32 width,
	uint32 height,
	RendererTextureHandle* outTextureHandle)
{
	Dx11Renderer* renderer = static_cast<Dx11Renderer*>(rendererHandle);

	if (renderer == nullptr ||
		outTextureHandle == nullptr ||
		*outTextureHandle != nullptr)
	{
		return RendererModuleResult::Failure;
	}

	return renderer->CreateTextureRgba8(
		rgbaPixels,
		byteCount,
		width,
		height,
		outTextureHandle) ?
		RendererModuleResult::Success :
		RendererModuleResult::Failure;
}

void DestroyTexture(
	RendererHandle rendererHandle,
	RendererTextureHandle textureHandle)
{
	Dx11Renderer* renderer = static_cast<Dx11Renderer*>(rendererHandle);

	if (renderer == nullptr)
	{
		return;
	}

	renderer->DestroyTexture(textureHandle);
}
```

And in `GetRendererModuleApi`:

```cpp
outRendererModuleApi->createTextureRgba8 = &CreateTextureRgba8;
outRendererModuleApi->destroyTexture = &DestroyTexture;
```

## 8. Project file manifest

`CyphenEngine.vcxproj`:

```xml
<ClInclude Include="Source\Core\Public\Codec.h" />
<ClInclude Include="Source\HAL\Private\PlatformCodec.h" />
<ClInclude Include="Source\Test\Common\TestHarness.h" />
<ClInclude Include="Source\Test\Renderer\RendererTest.h" />

<ClCompile Include="Source\Core\Private\Codec.cpp" />
<ClCompile Include="Source\Platform\Windows\Private\PlatformCodec.cpp" />
<ClCompile Include="Source\Test\Common\TestHarness.cpp" />
<ClCompile Include="Source\Test\Renderer\RendererTest.cpp" />
```

Remove old `TextCodec.h/.cpp` items.

Add Debug resource copy target:

```xml
<Target Name="CopyThumbnailResources" AfterTargets="Build" Condition="'$(Configuration)'=='Debug'">
  <ItemGroup>
    <ThumbnailResources Include="Resources\Thumbnail\**\*.*" />
  </ItemGroup>
  <Copy SourceFiles="@(ThumbnailResources)"
        DestinationFiles="@(ThumbnailResources->'$(OutDir)Resources\Thumbnail\%(RecursiveDir)%(Filename)%(Extension)')"
        SkipUnchangedFiles="true" />
</Target>
```

`CyphenRendererDx11.vcxproj`:

```xml
<AdditionalDependencies>d3dcompiler.lib;%(AdditionalDependencies)</AdditionalDependencies>
```

## 9. Expected runtime path

```text
Launch Debug
    -> RunCoreIoTests
    -> StartEngineThread
    -> RunModuleTests
    -> RunRendererTests

RendererTests
    -> FileSystem::FileExists(Profile/Profile2)
    -> File::ReadAllBytes
    -> Codec::DecodeImageRgba8
    -> PlatformCodec::DecodeJpegToRgba8 (WIC)
    -> CyphenEngine::SubmitDebugTextureSource

Renderer thread
    -> DrainDebugTextureSource
    -> RendererModuleApi.createTextureRgba8
    -> BuildRenderCommandList
    -> DrawTexturedQuad(handle)
    -> Present
```
