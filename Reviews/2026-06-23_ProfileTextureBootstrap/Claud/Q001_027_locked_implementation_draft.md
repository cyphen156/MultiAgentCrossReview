Date: 2026-06-24
Question-ID: Q001
Author: Claude
Responds-To: 06-24 세션 락 합의(공통 ModuleCommand 직접 사용 / RenderCommandBuffer·Encoder 폐기 / UploadResource=임시 resource-sync / layout은 renderer 도메인 소유) + 사용자 "구현해와"
Supersedes: none (구현 초안; 설계 계약은 Q001_026 + 본 기록으로 고정)
Status: Implementation-Draft
Baseline: Codex 세션 019ef3d6(06-24) 합의. 원본/미러 미적용. 적용·빌드·커밋은 사용자.

# #2_6 락된 설계 구현 초안

워크벤치는 읽기 전용 → 본 기록은 **드롭인 초안**이다. 사용자가 원본(`C:\Project\CyphenEngine`)에 적용한다.
스타일: Allman, 탭, 람다 금지(익명 namespace 명명 헬퍼), C~ 타입, static-only 클래스 삭제자 명시,
ABI 구조체 static_assert, boolean Is/Has/Can.

## 0. 락된 경계 (구현이 지켜야 할 불변)

```text
ModuleCommandBuffer   공통 transport. 직접 사용. 도메인 타입 모름.
RenderCommand.h       계약: RenderCommandType enum + payload struct (engine writer ↔ backend 공유)
RenderCommandWrite    renderer 도메인 자유함수. UploadResource layout을 캡슐화(= "API가 명세대로 내부에서 깐다").
                      호출자는 의도만 전달. Texture2D를 아는 유일한 engine-side 지점. 클래스 아님.
Backend(Dx11)         commandType 해석 + ResourceId→GPU object table 소유/실행.
부트스트랩(RendererTest) File→Codec→Texture2D, upload list 1회 + frame list 매 프레임.
```

핵심: **upload와 draw는 같은 IR이지만 다른 제출** — upload-list는 부팅 1회, frame-list는 매 프레임.
`UploadResource`는 draw가 아니라 임시 resource-sync 명령(미래 RHI command의 임시 위치).

---

## 1. Resource 레이어 (`Source/Resource`)

### Source/Resource/Public/Resource.h
```cpp
#pragma once

#include "Core/Public/CPrimitiveTypes.h"

// ============================================================================
// Resource
// ----------------------------------------------------------------------------
// Runtime resource 공통 header.
// resourceId는 CPU Resource와 backend GPU resource table을 잇는 logical key다.
// hot path(Frame/RenderCommand)는 ResourceId만 참조한다.
// ============================================================================

using ResourceId = uint64;

constexpr ResourceId InvalidResourceId = 0;

enum class ResourceKind : uint32
{
	Unknown = 0,
	Texture2D = 1
};

struct Resource
{
	ResourceId resourceId = InvalidResourceId;
	ResourceKind kind = ResourceKind::Unknown;
};
```

### Source/Resource/Public/Texture.h
```cpp
#pragma once

#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Resource/Public/Resource.h"

// ============================================================================
// TextureFormat / Texture2D
// ----------------------------------------------------------------------------
// #2_6은 RGBA8만. Texture2D는 CPU-side 데이터다(GPU object 아님, backend pointer 아님).
// ============================================================================

enum class TextureFormat : uint32
{
	Unknown = 0,
	Rgba8 = 1
};

struct Texture2D : public Resource
{
	Texture2D();

	TextureFormat format = TextureFormat::Unknown;
	std::vector<uint8> pixels;
	uint32 width = 0;
	uint32 height = 0;
};

// ============================================================================
// Texture2DUploadPayloadHeader
// ----------------------------------------------------------------------------
// UploadResource payload 안에서 raw pixel bytes 앞에 붙는 texture-specific header.
// RenderCommand type이 아니라 Resource payload metadata다. backend가 이것으로 해석한다.
// ============================================================================

struct Texture2DUploadPayloadHeader
{
	TextureFormat format = TextureFormat::Unknown;
	uint32 width = 0;
	uint32 height = 0;
	uint64 byteCount = 0;
};

static_assert(sizeof(Texture2DUploadPayloadHeader) == 24,
	"Texture2DUploadPayloadHeader must be 24 bytes.");
```

### Source/Resource/Private/Texture.cpp
```cpp
#include "pch.h"

#include "Resource/Public/Texture.h"

Texture2D::Texture2D()
{
	kind = ResourceKind::Texture2D;
}
```

---

## 2. Content Codec (Resource로 decode)

코덱 계층/본문은 06-24 세션 1/4 초안과 동일하므로 시그니처만 고정한다. (WIC 본문은 Codex
`Q001_022`/세션 1/4의 `WindowsJpegCodec::Decode` 그대로 — `Texture2D&`로 기록, `byteCount` 검증 포함.)

```cpp
// Source/Content/Public/Codec.h
class Codec final
{
public:
	static bool Decode(const CString& sourcePath,
		const std::vector<uint8>& bytes, Resource& outResource);   // ResourceKind로 dispatch
private: /* 삭제자 명시 */ };

// Source/Content/Private/Image/ImageCodec.h  (확장자 table+switch → JpegCodec)
// Source/Content/Private/Image/Jpeg/JpegCodec.h  (leaf → WindowsJpegCodec)
// Source/Content/Private/Image/Jpeg/WindowsJpegCodec.h/.cpp  (WIC, Texture2D& 기록)
```

```cpp
// Source/Core/Public/Path.h 추가
static CString GetExtensionLower(const CString& path);

// Source/Core/Private/Path.cpp 추가
CString Path::GetExtensionLower(const CString& path)
{
	CString extension = GetExtension(path);

	for (CChar& character : extension)
	{
		if (character >= CTEXT("A")[0] && character <= CTEXT("Z")[0])
		{
			character = static_cast<CChar>(character - CTEXT("A")[0] + CTEXT("a")[0]);
		}
	}

	return extension;
}
```

> ⚠️ 미해결(Q026 쟁점1): `WindowsJpegCodec`을 `Content/.../Jpeg`(현 세션안) vs `Platform/Windows`(PlatformFile
> 선례)에 둘지. 본 초안은 세션안(Content)을 따르되, OS-경계 일관성을 원하면 WIC 본문만 `Platform/Windows/
> Private/WindowsJpegCodec.cpp`로 옮기고 `Content`엔 선언/위임만 남기면 된다(전환 비용 작음).

---

## 3. RenderCommand 계약 (`Source/Modules/Renderer/Public/RenderCommand.h`)

```cpp
#pragma once

#include "Modules/Public/ModuleCommand.h"
#include "Resource/Public/Resource.h"

// ============================================================================
// RenderCommand IR  (ModuleCommand transport 위의 Renderer 도메인 어휘)
//
// 명령 부류:
//   [Frame/Draw]      ClearRenderTarget / Present / DrawTexturedQuad   (매 프레임, 재생성)
//   [Resource-Sync]   UploadResource / DestroyResource                 (프레임 아님; 1회/수명 이벤트)
//                     ※ 임시 위치. 미래 RHI/ResourceManager command queue로 추출 예정.
//
// 추출 대비 번호대 분리: Frame/Draw 1~99, Resource-Sync 100~.
// ============================================================================

enum class RenderCommandType : uint32
{
	None = 0,

	// Frame / Draw
	ClearRenderTarget = 1,
	Present = 2,
	DrawTexturedQuad = 3,

	// Resource-Sync (future RHI)
	UploadResource = 100,
	DestroyResource = 101
};

using RenderCommandWord = ModuleCommandWord;
using RenderCommandList = ModuleCommandList;

struct ClearRenderTargetCommand
{
	float color[4] = {};
};

struct DrawTexturedQuadCommand
{
	ResourceId textureId = InvalidResourceId;
};

// payload layout: UploadResourceCommand → <kind-specific header> → raw bytes
struct UploadResourceCommand
{
	ResourceId resourceId = InvalidResourceId;
	ResourceKind resourceKind = ResourceKind::Unknown;
	uint64 payloadByteCount = 0;   // kind-specific header + raw bytes의 정확 바이트 수
};

struct DestroyResourceCommand
{
	ResourceId resourceId = InvalidResourceId;
};

static_assert(sizeof(ClearRenderTargetCommand) == 16, "ClearRenderTargetCommand must be 16 bytes.");
static_assert(sizeof(DrawTexturedQuadCommand) == 8, "DrawTexturedQuadCommand must be 8 bytes.");
static_assert(sizeof(UploadResourceCommand) == 24, "UploadResourceCommand must be 24 bytes.");
static_assert(sizeof(DestroyResourceCommand) == 8, "DestroyResourceCommand must be 8 bytes.");
```

### Source/Modules/Renderer/Public/Frame.h
```cpp
#pragma once

#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Resource/Public/Resource.h"

struct TexturedQuadDrawItem
{
	ResourceId textureId = InvalidResourceId;
};

// Frame은 ResourceId만. 리소스 bytes/CPU Texture2D를 들지 않는다.
struct Frame
{
	uint64 frameNumber = 0;
	std::vector<TexturedQuadDrawItem> texturedQuadDrawItems;
};
```

---

## 4. Renderer 도메인 write 헬퍼 (layout 소유, 클래스 아님)

`RenderCommandBuffer`/`Encoder`는 만들지 않는다. 대신 **renderer 도메인 자유함수**가 payload layout을
캡슐화하고 `ModuleCommandBuffer`에 직접 append한다. 이게 "API가 명세대로 내부에서 깐다 / 호출자는 의도만"의
실체다. Texture2D를 아는 engine-side 유일 지점이며, transport 버퍼는 순수하게 유지된다.

### Source/Modules/Renderer/Public/RenderCommandWrite.h
```cpp
#pragma once

#include "Core/Public/CPrimitiveTypes.h"
#include "Modules/Public/ModuleCommandBuffer.h"
#include "Resource/Public/Resource.h"

struct Texture2D;

// Renderer 도메인 command를 ModuleCommandBuffer에 기록한다.
// 책임: RenderCommand payload 구성/검증 + AppendCommand 위임.
// 비책임: command stream 저장정책 / File·Codec / backend 실행.
namespace RenderCommandWrite
{
	bool AppendClearRenderTarget(ModuleCommandBuffer& buffer, float r, float g, float b, float a);
	bool AppendPresent(ModuleCommandBuffer& buffer);
	bool AppendDrawTexturedQuad(ModuleCommandBuffer& buffer, ResourceId textureId);

	bool AppendUploadResource(ModuleCommandBuffer& buffer, const Resource& resource);  // kind로 분기
	bool AppendDestroyResource(ModuleCommandBuffer& buffer, ResourceId resourceId);
}
```

### Source/Modules/Renderer/Private/RenderCommandWrite.cpp
```cpp
#include "pch.h"

#include "Modules/Renderer/Public/RenderCommandWrite.h"

#include <cstring>
#include <limits>
#include <vector>

#include "Modules/Renderer/Public/RenderCommand.h"
#include "Resource/Public/Texture.h"

namespace
{
	bool IsValidTexture2DUploadSource(const Texture2D& texture)
	{
		return texture.kind == ResourceKind::Texture2D &&
			texture.resourceId != InvalidResourceId &&
			texture.format == TextureFormat::Rgba8 &&
			texture.width > 0 &&
			texture.height > 0 &&
			static_cast<uint64>(texture.pixels.size()) ==
				static_cast<uint64>(texture.width) * texture.height * 4;
	}

	bool CanStoreAsU32(uint64 value)
	{
		return value <= static_cast<uint64>(std::numeric_limits<uint32>::max());
	}

	bool AppendUploadTexture2D(ModuleCommandBuffer& buffer, const Texture2D& texture)
	{
		if (IsValidTexture2DUploadSource(texture) == false)
		{
			return false;
		}

		Texture2DUploadPayloadHeader header = {};
		header.format = texture.format;
		header.width = texture.width;
		header.height = texture.height;
		header.byteCount = static_cast<uint64>(texture.pixels.size());

		UploadResourceCommand command = {};
		command.resourceId = texture.resourceId;
		command.resourceKind = ResourceKind::Texture2D;
		command.payloadByteCount =
			static_cast<uint64>(sizeof(header)) + header.byteCount;

		const uint64 totalSize =
			static_cast<uint64>(sizeof(command)) + command.payloadByteCount;

		if (CanStoreAsU32(totalSize) == false)
		{
			return false;
		}

		std::vector<uint8> payload;
		payload.resize(static_cast<size_t>(totalSize));

		uint8* cursor = payload.data();
		std::memcpy(cursor, &command, sizeof(command));
		cursor += sizeof(command);
		std::memcpy(cursor, &header, sizeof(header));
		cursor += sizeof(header);
		std::memcpy(cursor, texture.pixels.data(), texture.pixels.size());

		return buffer.AppendCommand(
			static_cast<uint32>(RenderCommandType::UploadResource),
			payload.data(),
			static_cast<uint32>(payload.size()));
	}
}

namespace RenderCommandWrite
{
	bool AppendClearRenderTarget(ModuleCommandBuffer& buffer, float r, float g, float b, float a)
	{
		ClearRenderTargetCommand command = {};
		command.color[0] = r;
		command.color[1] = g;
		command.color[2] = b;
		command.color[3] = a;

		return buffer.AppendCommand(
			static_cast<uint32>(RenderCommandType::ClearRenderTarget),
			&command,
			static_cast<uint32>(sizeof(command)));
	}

	bool AppendPresent(ModuleCommandBuffer& buffer)
	{
		return buffer.AppendCommand(
			static_cast<uint32>(RenderCommandType::Present), nullptr, 0);
	}

	bool AppendDrawTexturedQuad(ModuleCommandBuffer& buffer, ResourceId textureId)
	{
		if (textureId == InvalidResourceId)
		{
			return false;
		}

		DrawTexturedQuadCommand command = {};
		command.textureId = textureId;

		return buffer.AppendCommand(
			static_cast<uint32>(RenderCommandType::DrawTexturedQuad),
			&command,
			static_cast<uint32>(sizeof(command)));
	}

	bool AppendUploadResource(ModuleCommandBuffer& buffer, const Resource& resource)
	{
		if (resource.resourceId == InvalidResourceId)
		{
			return false;
		}

		switch (resource.kind)
		{
		case ResourceKind::Texture2D:
			return AppendUploadTexture2D(buffer, static_cast<const Texture2D&>(resource));

		default:
			return false;
		}
	}

	bool AppendDestroyResource(ModuleCommandBuffer& buffer, ResourceId resourceId)
	{
		if (resourceId == InvalidResourceId)
		{
			return false;
		}

		DestroyResourceCommand command = {};
		command.resourceId = resourceId;

		return buffer.AppendCommand(
			static_cast<uint32>(RenderCommandType::DestroyResource),
			&command,
			static_cast<uint32>(sizeof(command)));
	}
}
```

---

## 5. Backend(Dx11) 명령 해석 — 3/4 (세션 미도달분)

#2_5의 device/swapchain/RTV/Clear/Present는 이미 존재한다고 가정. 추가분만 기술한다.
ABI(`RendererModuleApi`)는 늘리지 않는다 — 전부 `executeCommandList` 한 통로.

### GPU resource table + 추가 멤버 (Dx11Renderer)
```cpp
// Dx11Renderer.h 추가
#include <unordered_map>
#include <wrl/client.h>

struct Dx11GpuTexture
{
	Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> srv;
};

// private 멤버
std::unordered_map<ResourceId, Dx11GpuTexture> gpuTextures;     // ResourceId → GPU object
// textured quad pipeline (1회 생성): VS/PS/InputLayout/VB/IB/Sampler/BlendState
```

### Execute dispatch
```cpp
// Dx11Renderer.cpp (command 루프 내부, header.commandType 기준)
switch (static_cast<RenderCommandType>(header.commandType))
{
case RenderCommandType::ClearRenderTarget:  ExecuteClear(payload, payloadWordCount);          break;
case RenderCommandType::Present:            ExecutePresent();                                  break;
case RenderCommandType::DrawTexturedQuad:   ExecuteDrawTexturedQuad(payload, payloadWordCount); break;
case RenderCommandType::UploadResource:     ExecuteUploadResource(payload, payloadWordCount);  break;
case RenderCommandType::DestroyResource:    ExecuteDestroyResource(payload, payloadWordCount); break;
default: break;   // 미지 commandType은 무시(전방호환)
}
```

### UploadResource → Texture2D 생성 (byteCount로 정확 추출 — Q026 쟁점2)
```cpp
bool Dx11Renderer::ExecuteUploadResource(const RenderCommandWord* payloadWords, uint32 payloadWordCount)
{
	if (static_cast<uint64>(payloadWordCount) * sizeof(RenderCommandWord) < sizeof(UploadResourceCommand))
	{
		return false;
	}

	UploadResourceCommand command = {};
	std::memcpy(&command, payloadWords, sizeof(command));

	const uint8* payload = reinterpret_cast<const uint8*>(payloadWords) + sizeof(command);

	switch (command.resourceKind)
	{
	case ResourceKind::Texture2D:
		return ExecuteUploadTexture2D(command, payload);

	default:
		return false;
	}
}

bool Dx11Renderer::ExecuteUploadTexture2D(const UploadResourceCommand& command, const uint8* payload)
{
	Texture2DUploadPayloadHeader header = {};
	std::memcpy(&header, payload, sizeof(header));

	const uint8* pixels = payload + sizeof(header);

	// word padding이 아니라 byteCount로 자른다. 그리고 크기/포맷 재검증.
	if (header.format != TextureFormat::Rgba8 ||
		header.width == 0 || header.height == 0 ||
		header.byteCount != static_cast<uint64>(header.width) * header.height * 4 ||
		command.payloadByteCount != static_cast<uint64>(sizeof(header)) + header.byteCount)
	{
		return false;
	}

	D3D11_TEXTURE2D_DESC desc = {};
	desc.Width = header.width;
	desc.Height = header.height;
	desc.MipLevels = 1;
	desc.ArraySize = 1;
	desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	desc.SampleDesc.Count = 1;
	desc.Usage = D3D11_USAGE_IMMUTABLE;
	desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;

	D3D11_SUBRESOURCE_DATA initData = {};
	initData.pSysMem = pixels;
	initData.SysMemPitch = header.width * 4;

	Dx11GpuTexture gpuTexture;
	if (FAILED(device->CreateTexture2D(&desc, &initData, gpuTexture.texture.GetAddressOf())))
	{
		return false;
	}
	if (FAILED(device->CreateShaderResourceView(
		gpuTexture.texture.Get(), nullptr, gpuTexture.srv.GetAddressOf())))
	{
		return false;
	}

	gpuTextures[command.resourceId] = std::move(gpuTexture);   // ResourceId 키 등록
	return true;
}
```

### DrawTexturedQuad → table 조회 후 그림
```cpp
bool Dx11Renderer::ExecuteDrawTexturedQuad(const RenderCommandWord* payloadWords, uint32 payloadWordCount)
{
	DrawTexturedQuadCommand command = {};
	std::memcpy(&command, payloadWords, sizeof(command));

	const auto found = gpuTextures.find(command.textureId);
	if (found == gpuTextures.end())
	{
		return false;   // 아직 resident 아님(upload 누락/순서 오류)
	}

	ID3D11ShaderResourceView* srv = found->second.srv.Get();

	// quad pipeline 바인딩(1회 생성된 VS/PS/IL/VB/IB/Sampler) + SRV + Draw
	deviceContext->IASetInputLayout(quadInputLayout.Get());
	const UINT stride = sizeof(QuadVertex);
	const UINT offset = 0;
	deviceContext->IASetVertexBuffers(0, 1, quadVertexBuffer.GetAddressOf(), &stride, &offset);
	deviceContext->IASetIndexBuffer(quadIndexBuffer.Get(), DXGI_FORMAT_R16_UINT, 0);
	deviceContext->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
	deviceContext->VSSetShader(quadVertexShader.Get(), nullptr, 0);
	deviceContext->PSSetShader(quadPixelShader.Get(), nullptr, 0);
	deviceContext->PSSetShaderResources(0, 1, &srv);
	deviceContext->PSSetSamplers(0, 1, quadSampler.GetAddressOf());
	deviceContext->DrawIndexed(6, 0, 0);
	return true;
}
```

### DestroyResource
```cpp
bool Dx11Renderer::ExecuteDestroyResource(const RenderCommandWord* payloadWords, uint32 payloadWordCount)
{
	DestroyResourceCommand command = {};
	std::memcpy(&command, payloadWords, sizeof(command));
	gpuTextures.erase(command.resourceId);   // ComPtr 소멸 → GPU object 해제
	return true;
}
```

> quad VS/PS는 first-light용 d3dcompiler 런타임 컴파일 inline HLSL(전체화면/사각 quad + sampler)로
> 충분(Decision 잔여선택). 셰이더/VB·IB 생성은 backend 초기화 1회. `gpuTextures`는 `destroyRenderer`
> 이전에 비운다(Q012 destroy-before-teardown 승계).

---

## 6. 부트스트랩 (RendererTest, `#ifdef _DEBUG`) — upload 1회 / draw 매 프레임

```cpp
// Source/Test/Renderer/RendererTest.cpp (요지)
#ifdef _DEBUG
// (a) fixture 로드 — Main thread 측 CPU 준비
Texture2D profile;
profile.resourceId = 1;   // #2_6 임시 수동 ID (추후 ResourceManager allocator) — Q026 쟁점3
std::vector<uint8> bytes;
if (FileSystem::FileExists(CTEXT("Resources/Thumbnail/Profile.jpg")) &&
	File::ReadAllBytes(CTEXT("Resources/Thumbnail/Profile.jpg"), bytes) &&
	Codec::Decode(CTEXT("Resources/Thumbnail/Profile.jpg"), bytes, profile))
{
	// (b) upload list — 1회 제출 (render thread에서 GPU 생성)
	ModuleCommandBuffer uploadBuffer;
	RenderCommandWrite::AppendUploadResource(uploadBuffer, profile);
	renderer.ExecuteCommandList(uploadBuffer.GetCommandList());   // backend가 ResourceId 1 등록

	debugTextureId = profile.resourceId;   // 이후 frame draw가 참조
}
#endif

// 매 프레임 frame list — upload는 여기 없음
ModuleCommandBuffer frameBuffer;
RenderCommandWrite::AppendClearRenderTarget(frameBuffer, 0.05f, 0.08f, 0.12f, 1.0f);
#ifdef _DEBUG
if (debugTextureId != InvalidResourceId)
{
	RenderCommandWrite::AppendDrawTexturedQuad(frameBuffer, debugTextureId);
}
#endif
RenderCommandWrite::AppendPresent(frameBuffer);
renderer.ExecuteCommandList(frameBuffer.GetCommandList());
```

Profile2는 `resourceId = 2`로 동일 절차(부팅 시 둘 다 upload, 기본 1장 draw + 교체 fixture).

---

## 7. 적용 체크리스트 / 미해결

- vcxproj: `Source/Resource/**`, `Source/Content/**`, `RenderCommandWrite.*`, `Source/Test/Renderer/**` 추가.
  Thumbnail 리소스 Debug 복사 Target + Profile.jpg/Profile2.jpg 항목 등록(Decision 9항, 미변).
- 합격 기준(Decision): Debug x64 창에 Profile.jpg 표시 + ModuleTests/RendererTests 통과.
- **미해결(설계 차단 아님)**: ① WindowsJpegCodec 위치(Content vs Platform/Windows) ② ResourceId 발급은
  #2_6 수동, ResourceManager 도입 시 allocator로 ③ 셰이더 inline HLSL 임시 ④ 테스트 3분리/출력 sink
  일원화(Decision 7·8항)는 본 IR 초안과 독립, 그대로 진행.
- **불변 재확인**: ABI 미증가 / Frame=ResourceId만 / transport=ModuleCommand 직접 / RenderCommandBuffer·
  Encoder 없음 / upload·draw 분리 제출 / backend가 GPU table 소유.
