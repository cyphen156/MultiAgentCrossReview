Date: 2026-06-22
Question-ID: Q001
Author: Codex
Responds-To: user cross-review
Supersedes: none
Status: Revision-Complete
Baseline: 2026-06-22 workspace mirror

# 결론

현재 `moduleName == DLL basename`인 1:1 부트스트랩을 다음 세 식별자로 분리한다.

```text
moduleName          Renderer
implementationName  Dx11
binaryName          CyphenRendererDx11
```

이 변경은 패키지 시스템 전체를 구현하지 않는다. 다만 이후 Manifest나 복수 Backend가 추가되어도 Module과 Binary를 다시 분해하지 않도록 현재 데이터·상태·조회 경계를 고정한다.

# 완결 구현 범위

## 1. ModuleDescriptor

```cpp
#pragma once

#include "Core/Public/CString.h"

// ============================================================================
// ModuleDescriptor
// ----------------------------------------------------------------------------
// 이번 실행에서 사용할 엔진 모듈과 선택 구현을 기술하는 선언형 값입니다.
//
// moduleName:
//   기능 패키지를 식별하는 논리적 모듈 이름입니다.
//
// implementationName:
//   이번 실행에서 선택된 구현 이름입니다.
//
// binaryName:
//   플랫폼 확장자를 제외한 네이티브 구현 Binary 이름입니다.
//
// isEnabled:
//   이번 실행에서 모듈을 활성화할지 나타냅니다.
// ============================================================================

struct ModuleDescriptor
{
	CString moduleName;
	CString implementationName;
	CString binaryName;
	bool isEnabled = false;
};
```

## 2. ModuleManager 상태 기준

- Descriptor, Record, LoadOrder의 키는 `moduleName`이다.
- `ModuleLoader::Load()`에만 `binaryName`을 전달한다.
- `ModuleRecord`는 현재 적재된 `implementationName`, `binaryName`, native handle을 보관한다.
- 활성 모듈의 선택 구현 또는 Binary가 바뀌면 `Refresh()`에서 기존 구현을 언로드한다.
- Descriptor 교체 후 활성 상태인 새 구현을 다시 로드한다.
- `FindSymbol("Renderer", ...)`는 Renderer의 현재 선택 구현 Binary에서 심볼을 찾는다.

핵심 Record:

```cpp
struct ModuleRecord
{
	CString implementationName;
	CString binaryName;
	void* nativeHandle = nullptr;
};
```

구현 변경 감지:

```cpp
bool shouldUnload = descriptorIterator == refreshedDescriptors.end() ||
	descriptorIterator->second.isEnabled == false;

if (shouldUnload == false)
{
	auto recordIterator = gModuleRecords.find(*moduleIterator);

	if (recordIterator == gModuleRecords.end() ||
		recordIterator->second.implementationName != descriptorIterator->second.implementationName ||
		recordIterator->second.binaryName != descriptorIterator->second.binaryName)
	{
		shouldUnload = true;
	}
}
```

Binary 적재:

```cpp
const ModuleDescriptor& moduleDescriptor = descriptorIterator->second;

if (moduleDescriptor.implementationName.empty() || moduleDescriptor.binaryName.empty())
{
	return false;
}

void* nativeHandle = nullptr;

if (ModuleLoader::Load(moduleDescriptor.binaryName, nativeHandle) == false)
{
	return false;
}

ModuleRecord moduleRecord;
moduleRecord.implementationName = moduleDescriptor.implementationName;
moduleRecord.binaryName = moduleDescriptor.binaryName;
moduleRecord.nativeHandle = nativeHandle;
```

## 3. Renderer Backend 계약

`RendererModule.h`는 `RendererBackend.h`로 변경한다.

```cpp
#pragma once

#include "Core/Public/CChar.h"
#include "Core/Public/CPrimitiveTypes.h"
#include "Modules/Renderer/Public/RendererTypes.h"

#ifdef _DEBUG
constexpr uint32 RENDERER_BACKEND_DEVELOPMENT_VERSION = 1;
constexpr uint32 RENDERER_BACKEND_API_VERSION = RENDERER_BACKEND_DEVELOPMENT_VERSION;
#else
constexpr uint32 RENDERER_BACKEND_API_VERSION = 1;
#endif

constexpr const CChar RENDERER_MODULE_NAME[] = CTEXT("Renderer");
constexpr const char GET_RENDERER_BACKEND_API_NAME[] = "GetRendererBackendApi";

enum class RendererBackendResult : uint32
{
	Failure = 0,
	Success = 1
};

struct RendererBackendApi
{
	uint32 apiVersion = 0;
	RendererType rendererType = RendererType::None;
};

using GetRendererBackendApiFunction =
	RendererBackendResult(*)(RendererBackendApi* outRendererBackendApi);
```

이번 단계에서는 Backend 실행 함수, Render Thread, Command Queue를 추가하지 않는다. 계약 이름과 조회 경계만 바로잡는다.

## 4. Renderer 연결

Renderer는 로드된 모든 Binary를 순회하지 않는다. 논리 Module `Renderer`에 연결된 선택 구현만 조회한다.

```cpp
#include "pch.h"

#include "Core/Public/ModuleManager.h"
#include "Modules/Renderer/Public/Renderer.h"
#include "Modules/Renderer/Public/RendererBackend.h"

static RendererBackendApi gRendererBackendApi = {};

bool Renderer::Initialize()
{
	if (IsInitialized())
	{
		return false;
	}

	ModuleSymbol moduleSymbol = ModuleManager::FindSymbol(
		RENDERER_MODULE_NAME, GET_RENDERER_BACKEND_API_NAME);

	if (moduleSymbol == nullptr)
	{
		return false;
	}

	GetRendererBackendApiFunction getRendererBackendApi =
		reinterpret_cast<GetRendererBackendApiFunction>(moduleSymbol);

	RendererBackendApi rendererBackendApi = {};

	if (getRendererBackendApi(&rendererBackendApi) != RendererBackendResult::Success)
	{
		return false;
	}

	if (rendererBackendApi.apiVersion != RENDERER_BACKEND_API_VERSION)
	{
		return false;
	}

	if (rendererBackendApi.rendererType == RendererType::None)
	{
		return false;
	}

	gRendererBackendApi = rendererBackendApi;

	return true;
}

void Renderer::Shutdown()
{
	gRendererBackendApi = {};
}

bool Renderer::IsInitialized()
{
	return gRendererBackendApi.rendererType != RendererType::None;
}

RendererType Renderer::GetRendererType()
{
	return gRendererBackendApi.rendererType;
}
```

## 5. DX11 Backend export

```cpp
#include "Modules/Renderer/Public/RendererBackend.h"

extern "C" __declspec(dllexport)
RendererBackendResult GetRendererBackendApi(RendererBackendApi* outRendererBackendApi)
{
	if (outRendererBackendApi == nullptr)
	{
		return RendererBackendResult::Failure;
	}

	outRendererBackendApi->apiVersion = RENDERER_BACKEND_API_VERSION;
	outRendererBackendApi->rendererType = RendererType::Dx11;

	return RendererBackendResult::Success;
}
```

## 6. Launch Descriptor와 순서

```cpp
ModuleDescriptor rendererModule;
rendererModule.moduleName = CTEXT("Renderer");
rendererModule.implementationName = CTEXT("Dx11");
rendererModule.binaryName = CTEXT("CyphenRendererDx11");
rendererModule.isEnabled = true;

launchContext.moduleDescriptors.push_back(rendererModule);
```

Module 준비는 Engine 초기화 전에 수행한다.

```cpp
bool Launch::StartEngineThread(const LaunchContext& launchContext)
{
	if (ModuleManager::Refresh(launchContext.moduleDescriptors) == false)
	{
		ModuleManager::Shutdown();
		return false;
	}

	if (engineInstance.InitEngine(launchContext) == false)
	{
		ModuleManager::Shutdown();
		return false;
	}

	engineThread = std::thread(&CyphenEngine::Run, &engineInstance);

	return true;
}
```

Engine Thread 종료 뒤 구현 Binary를 언로드한다.

```cpp
void Launch::JoinEngineThread()
{
	if (engineThread.joinable())
	{
		engineThread.join();
	}

	const bool isModuleShutdownSuccessful = ModuleManager::Shutdown();

#ifdef _DEBUG
	_ASSERT(isModuleShutdownSuccessful);
#endif

	(void)isModuleShutdownSuccessful;
}
```

## 7. Engine의 Renderer 시스템 연결

`CyphenEngine::InitEngine()`은 ModuleManager를 호출하지 않는다. 이미 준비된 Renderer Module의 Backend 계약만 연결한다.

```cpp
if (Renderer::Initialize() == false)
{
	return false;
}
```

`ShutdownEngine()`에서는 Binary 언로드 전에 Renderer 참조를 제거한다.

```cpp
Renderer::Shutdown();
engineStatus.store(Terminated);
```

## 8. 프로젝트 파일

- `RendererModule.h` 항목을 `RendererBackend.h`로 변경한다.
- `Dx11RendererModule.cpp`는 `Dx11RendererBackend.cpp`로 변경한다.
- Engine과 DX11 프로젝트의 include/compile 항목 및 filters를 함께 변경한다.
- `CyphenRendererDx11` 프로젝트명과 DLL명은 유지한다.

# 정적 검증 기준

```text
ModuleManager map key          logical moduleName
ModuleLoader::Load argument   binaryName
Renderer symbol lookup key    Renderer
Renderer exported contract    RendererBackendApi
DX11 native binary            CyphenRendererDx11
```

다음 문자열이 코드 참조에서 제거되어야 한다.

```text
RendererModuleApi
GetRendererModuleApi
GET_RENDERER_MODULE_API_NAME
Dx11RendererModule.cpp
```

# 제외 범위

- Module Manifest와 설치 탐색
- Module 의존성 그래프
- 여러 설치 구현 중 자동 선택
- Renderer Thread와 Command Queue
- Backend 생성·파괴·명령 실행 함수
- 실제 DX11 Device/Context/SwapChain
