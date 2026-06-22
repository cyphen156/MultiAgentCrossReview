Date: 2026-06-22
Question-ID: Q001
Author: Codex
Responds-To: user final architecture decision, Claud/Q001_003_cross_review_codex.md
Supersedes: Codex/Q001_004_cross_review_claude.md
Status: Revision-Complete
Baseline: 2026-06-22 workspace mirror

# #2_3 Renderer Module binding lifetime — complete implementation proposal

The target mirror is read-only. The following is the complete source implementation to apply in the original repository. It intentionally excludes Render Thread, Command Queue, GPU lifecycle, capabilities, and ExecuteCommandList.

## Contract implemented

```text
Launch/Application
  ModuleManager::Refresh(desired descriptors)

Engine initialization order
  Renderer::Initialize
    ModuleBinding::Bind("Renderer")
      ModuleManager::Acquire
        first reference: LoadLibrary(binaryName)
        additional reference: reuse native handle
    GetRendererModuleApi
    validate apiVersion and rendererType

Engine shutdown order
  Renderer::Shutdown
    clear cached API
    ModuleBinding::Release
      final reference: FreeLibrary

After Engine thread join
  ModuleManager::Shutdown safety net
```

`Refresh` validates and stores desired state only. It performs no native load/unload. Invalid descriptors are skipped while valid descriptors are retained, and the aggregate result reports whether every descriptor was accepted.

If a descriptor changes while its old implementation is acquired, the existing binding continues to use its recorded binary. A new acquire is rejected until the existing references are released; the next acquire loads the newly desired implementation.

---

## New file — `CyphenEngine/Source/Core/Public/ModuleBinding.h`

```cpp
#pragma once

#include "Core/Public/CString.h"
#include "Core/Public/ModuleManager.h"

class ModuleBinding final
{
public:
	ModuleBinding() = default;
	~ModuleBinding() = default;

	ModuleBinding(const ModuleBinding& other) = delete;
	ModuleBinding& operator=(const ModuleBinding& other) = delete;

	ModuleBinding(ModuleBinding&& other) = delete;
	ModuleBinding& operator=(ModuleBinding&& other) = delete;

	bool Bind(const CString& moduleName);
	bool Release();

	ModuleSymbol FindSymbol(const char* symbolName) const;
	bool IsBound() const;

private:
	CString boundModuleName;
};
```

## New file — `CyphenEngine/Source/Core/Private/ModuleBinding.cpp`

```cpp
#include "pch.h"

#include "Core/Public/ModuleBinding.h"

bool ModuleBinding::Bind(const CString& moduleName)
{
	if (moduleName.empty())
	{
		return false;
	}

	if (IsBound())
	{
		return boundModuleName == moduleName;
	}

	if (ModuleManager::Acquire(moduleName) == false)
	{
		return false;
	}

	boundModuleName = moduleName;

	return true;
}

bool ModuleBinding::Release()
{
	if (IsBound() == false)
	{
		return true;
	}

	if (ModuleManager::Release(boundModuleName) == false)
	{
		return false;
	}

	boundModuleName.clear();

	return true;
}

ModuleSymbol ModuleBinding::FindSymbol(const char* symbolName) const
{
	if (IsBound() == false)
	{
		return nullptr;
	}

	return ModuleManager::FindSymbol(boundModuleName, symbolName);
}

bool ModuleBinding::IsBound() const
{
	return boundModuleName.empty() == false;
}
```

## Replace — `CyphenEngine/Source/Core/Public/ModuleManager.h`

```cpp
#pragma once

#include <vector>

#include "Core/Public/CString.h"
#include "Core/Public/ModuleDescriptor.h"

using ModuleSymbol = void*;

// ============================================================================
// ModuleManager
// ----------------------------------------------------------------------------
// Stores desired logical Module descriptors and owns loaded implementation
// binary handles. It does not interpret domain APIs or start Engine systems.
//
// Refresh updates desired descriptor state only. Acquire and Release control
// the native implementation binary reference lifetime.
//
// All public module names are logical ModuleDescriptor::moduleName values.
// Only ModuleLoader receives ModuleDescriptor::binaryName.
// ============================================================================

class ModuleManager final
{
public:
	static bool Refresh(const std::vector<ModuleDescriptor>& moduleDescriptors);
	static bool Shutdown();

	static bool Acquire(const CString& moduleName);
	static bool Release(const CString& moduleName);

	static ModuleSymbol FindSymbol(const CString& moduleName, const char* symbolName);

	static bool IsLoaded(const CString& moduleName);
	static void GetLoadedModuleNames(std::vector<CString>& outModuleNames);

private:
	ModuleManager() = delete;
	~ModuleManager() = delete;

	ModuleManager(const ModuleManager& other) = delete;
	ModuleManager& operator=(const ModuleManager& other) = delete;

	ModuleManager(ModuleManager&& other) = delete;
	ModuleManager& operator=(ModuleManager&& other) = delete;

	static bool UnloadAll();
};
```

## Replace — `CyphenEngine/Source/Core/Private/ModuleManager.cpp`

```cpp
#include "pch.h"

#include <map>
#include <vector>

#include "Core/Public/CPrimitiveTypes.h"
#include "Core/Public/ModuleManager.h"
#include "HAL/Private/ModuleLoader.h"

struct ModuleRecord
{
	CString implementationName;
	CString binaryName;
	void* nativeHandle = nullptr;
	uint32 referenceCount = 0;
};

static std::map<CString, ModuleDescriptor> gModuleDescriptors;
static std::map<CString, ModuleRecord> gModuleRecords;
static std::vector<CString> gModuleLoadOrder;

static bool RemoveModuleRecord(const CString& moduleName)
{
	auto moduleIterator = gModuleRecords.find(moduleName);

	if (moduleIterator == gModuleRecords.end())
	{
		return false;
	}

	if (ModuleLoader::Unload(moduleIterator->second.nativeHandle) == false)
	{
		return false;
	}

	gModuleRecords.erase(moduleIterator);

	for (auto loadOrderIterator = gModuleLoadOrder.begin();
		loadOrderIterator != gModuleLoadOrder.end();
		++loadOrderIterator)
	{
		if (*loadOrderIterator != moduleName)
		{
			continue;
		}

		gModuleLoadOrder.erase(loadOrderIterator);
		break;
	}

	return true;
}

bool ModuleManager::Refresh(const std::vector<ModuleDescriptor>& moduleDescriptors)
{
	std::map<CString, ModuleDescriptor> refreshedDescriptors;
	bool isRefreshSuccessful = true;

	for (const ModuleDescriptor& moduleDescriptor : moduleDescriptors)
	{
		bool isDescriptorValid = moduleDescriptor.moduleName.empty() == false;

		if (moduleDescriptor.isEnabled)
		{
			isDescriptorValid =
				isDescriptorValid &&
				moduleDescriptor.implementationName.empty() == false &&
				moduleDescriptor.binaryName.empty() == false;
		}

		if (isDescriptorValid == false)
		{
			isRefreshSuccessful = false;
			continue;
		}

		auto insertResult =
			refreshedDescriptors.emplace(moduleDescriptor.moduleName, moduleDescriptor);

		if (insertResult.second == false)
		{
			isRefreshSuccessful = false;
		}
	}

	gModuleDescriptors = refreshedDescriptors;

	return isRefreshSuccessful;
}

bool ModuleManager::Shutdown()
{
	if (UnloadAll() == false)
	{
		return false;
	}

	gModuleDescriptors.clear();

	return true;
}

bool ModuleManager::Acquire(const CString& moduleName)
{
	if (moduleName.empty())
	{
		return false;
	}

	auto descriptorIterator = gModuleDescriptors.find(moduleName);

	if (descriptorIterator == gModuleDescriptors.end())
	{
		return false;
	}

	const ModuleDescriptor& moduleDescriptor = descriptorIterator->second;

	if (moduleDescriptor.isEnabled == false ||
		moduleDescriptor.implementationName.empty() ||
		moduleDescriptor.binaryName.empty())
	{
		return false;
	}

	auto moduleIterator = gModuleRecords.find(moduleName);

	if (moduleIterator != gModuleRecords.end())
	{
		ModuleRecord& moduleRecord = moduleIterator->second;

		if (moduleRecord.implementationName != moduleDescriptor.implementationName ||
			moduleRecord.binaryName != moduleDescriptor.binaryName)
		{
			return false;
		}

		++moduleRecord.referenceCount;

		return true;
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
	moduleRecord.referenceCount = 1;

	auto insertResult = gModuleRecords.emplace(moduleName, moduleRecord);

	if (insertResult.second == false)
	{
		ModuleLoader::Unload(nativeHandle);
		return false;
	}

	gModuleLoadOrder.push_back(moduleName);

	return true;
}

bool ModuleManager::Release(const CString& moduleName)
{
	if (moduleName.empty())
	{
		return false;
	}

	auto moduleIterator = gModuleRecords.find(moduleName);

	if (moduleIterator == gModuleRecords.end())
	{
		return false;
	}

	ModuleRecord& moduleRecord = moduleIterator->second;

	if (moduleRecord.referenceCount == 0)
	{
		return false;
	}

	if (moduleRecord.referenceCount > 1)
	{
		--moduleRecord.referenceCount;
		return true;
	}

	return RemoveModuleRecord(moduleName);
}

ModuleSymbol ModuleManager::FindSymbol(const CString& moduleName, const char* symbolName)
{
	if (moduleName.empty())
	{
		return nullptr;
	}

	if (symbolName == nullptr || symbolName[0] == '\0')
	{
		return nullptr;
	}

	auto moduleIterator = gModuleRecords.find(moduleName);

	if (moduleIterator == gModuleRecords.end())
	{
		return nullptr;
	}

	return ModuleLoader::FindSymbol(moduleIterator->second.nativeHandle, symbolName);
}

bool ModuleManager::IsLoaded(const CString& moduleName)
{
	if (moduleName.empty())
	{
		return false;
	}

	return gModuleRecords.find(moduleName) != gModuleRecords.end();
}

void ModuleManager::GetLoadedModuleNames(std::vector<CString>& outModuleNames)
{
	outModuleNames = gModuleLoadOrder;
}

bool ModuleManager::UnloadAll()
{
	std::vector<CString> loadedModuleNames = gModuleLoadOrder;
	bool isAllUnloaded = true;

	for (auto moduleIterator = loadedModuleNames.rbegin();
		moduleIterator != loadedModuleNames.rend();
		++moduleIterator)
	{
		if (RemoveModuleRecord(*moduleIterator) == false)
		{
			isAllUnloaded = false;
		}
	}

	return isAllUnloaded;
}
```

## Replace — `CyphenEngine/Source/Modules/Renderer/Public/Renderer.h`

```cpp
#pragma once

#include "Modules/Renderer/Public/RendererTypes.h"

// ============================================================================
// Renderer
// ----------------------------------------------------------------------------
// Engine-facing facade for the logical Renderer Module.
//
// The Renderer system owns implementation binding state. The selected binary
// is only an implementation artifact and is acquired through ModuleBinding.
// ============================================================================

namespace Renderer
{
	bool Initialize();
	void Shutdown();

	bool IsInitialized();
	RendererType GetRendererType();
}
```

## Replace — `CyphenEngine/Source/Modules/Renderer/Private/Renderer.cpp`

```cpp
#include "pch.h"

#include "Core/Public/CChar.h"
#include "Core/Public/ModuleBinding.h"
#include "Modules/Renderer/Public/Renderer.h"
#include "Modules/Renderer/Public/RendererModule.h"

namespace
{
	constexpr CChar RendererModuleName[] = CTEXT("Renderer");

	class RendererModule final
	{
	public:
		bool Initialize()
		{
			if (IsInitialized())
			{
				return false;
			}

			if (moduleBinding.Bind(RendererModuleName) == false)
			{
				return false;
			}

			ModuleSymbol moduleSymbol =
				moduleBinding.FindSymbol(GET_RENDERER_MODULE_API_NAME);

			if (moduleSymbol == nullptr)
			{
				moduleBinding.Release();
				return false;
			}

			GetRendererModuleApiFunction getRendererModuleApi =
				reinterpret_cast<GetRendererModuleApiFunction>(moduleSymbol);

			RendererModuleApi resolvedModuleApi = {};

			if (getRendererModuleApi(&resolvedModuleApi) != RendererModuleResult::Success)
			{
				moduleBinding.Release();
				return false;
			}

			if (resolvedModuleApi.apiVersion != RENDERER_MODULE_API_VERSION ||
				resolvedModuleApi.rendererType == RendererType::None)
			{
				moduleBinding.Release();
				return false;
			}

			moduleApi = resolvedModuleApi;

			return true;
		}

		void Shutdown()
		{
			moduleApi = {};

			const bool isReleased = moduleBinding.Release();

			#ifdef _DEBUG
			_ASSERT(isReleased);
			#endif

			(void)isReleased;
		}

		bool IsInitialized() const
		{
			return moduleBinding.IsBound() &&
				moduleApi.rendererType != RendererType::None;
		}

		RendererType GetRendererType() const
		{
			return moduleApi.rendererType;
		}

	private:
		ModuleBinding moduleBinding;
		RendererModuleApi moduleApi = {};
	};

	RendererModule gRendererModule;
}

bool Renderer::Initialize()
{
	return gRendererModule.Initialize();
}

void Renderer::Shutdown()
{
	gRendererModule.Shutdown();
}

bool Renderer::IsInitialized()
{
	return gRendererModule.IsInitialized();
}

RendererType Renderer::GetRendererType()
{
	return gRendererModule.GetRendererType();
}
```

## Replace — `CyphenEngine/Source/Engine/Private/CyphenEngine.cpp`

```cpp
#include "pch.h"

#include "Engine/Public/CyphenEngine.h"
#include "Core/Public/Time.h"
#include "Modules/Renderer/Public/Renderer.h"

CyphenEngine::CyphenEngine()
	: engineStatus(Initializing)
{
}

CyphenEngine::~CyphenEngine()
{
}

EngineStatus CyphenEngine::GetEngineStatus() const
{
	return engineStatus.load();
}

bool CyphenEngine::InitEngine(const LaunchContext& launchContext)
{
	if (engineStatus.load() != Initializing)
	{
		return false;
	}

	engineContext.nativeWindowHandle = launchContext.nativeWindowHandle;
	engineContext.windowWidth = launchContext.windowWidth;
	engineContext.windowHeight = launchContext.windowHeight;

	if (Time::Init() == false)
	{
		return false;
	}

	if (Renderer::Initialize() == false)
	{
		return false;
	}

	engineStatus.store(Ready);

	return true;
}

void CyphenEngine::Run()
{
	if (ChangeEngineStatus(Ready, Running) == false)
	{
		if (engineStatus.load() == Terminating)
		{
			ShutdownEngine();
		}

		return;
	}

	while (engineStatus.load() == Running)
	{
		Time::Tick();

		// TODO:
		// BUILD_TARGET based Runtime Tick
	}

	ShutdownEngine();
}

void CyphenEngine::ShutdownEngine()
{
	if (engineStatus.load() == Terminated)
	{
		return;
	}

	Renderer::Shutdown();
	engineStatus.store(Terminated);
}

bool CyphenEngine::RequestShutdown()
{
	EngineStatus currentStatus = engineStatus.load();

	while (currentStatus != Terminating && currentStatus != Terminated)
	{
		if (engineStatus.compare_exchange_strong(currentStatus, Terminating))
		{
			return true;
		}
	}

	return false;
}

bool CyphenEngine::ChangeEngineStatus(EngineStatus expected, EngineStatus desired)
{
	return engineStatus.compare_exchange_strong(expected, desired);
}
```

## Replace these complete functions — `CyphenEngine/Source/Platform/Windows/Private/Launch.cpp`

```cpp
bool Launch::StartEngineThread(const LaunchContext& launchContext)
{
	const bool isModuleRefreshSuccessful =
		ModuleManager::Refresh(launchContext.moduleDescriptors);

	#ifdef _DEBUG
	_ASSERT(isModuleRefreshSuccessful);
	#endif

	(void)isModuleRefreshSuccessful;

	if (engineInstance.InitEngine(launchContext) == false)
	{
		return false;
	}

	engineThread = std::thread(&CyphenEngine::Run, &engineInstance);

	return true;
}

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

The existing temporary descriptor block in `CreateLaunchContext` remains unchanged.

## Project entries — `CyphenEngine/CyphenEngine.vcxproj`

Add beside the other Core files:

```xml
<ClInclude Include="Source\Core\Public\ModuleBinding.h" />
<ClCompile Include="Source\Core\Private\ModuleBinding.cpp" />
```

No change is required in `RendererModule.h` or `Dx11RendererModule.cpp`. Their #2_3 contract remains `{apiVersion, rendererType}` and `GetRendererModuleApi`.

---

# Static verification

## Satisfied

- Module identity remains `moduleName / implementationName / binaryName`.
- `Refresh` no longer performs native I/O.
- Partial descriptor acceptance remains possible.
- Actual loading starts from `RendererModule::Initialize` through `ModuleBinding`.
- `Acquire/Release` prevents one binding from unloading another binding's native handle.
- Implementation changes cannot silently reuse the old binary for a new acquire.
- Renderer identity is private to the Renderer system; Launch does not include Renderer headers.
- Renderer binding and API state have one owner.
- No `IModule`, vtable, Render Thread, GPU context, capability, or Execute callback is introduced.
- Engine shutdown releases Renderer before the final ModuleManager safety shutdown.
- Duplicate `ModuleManager::Shutdown()` in `JoinEngineThread` is removed.

## Not executed in this workspace

Source application and build execution are prohibited by the review mirror rules. The proposal therefore has static verification only and must be applied and built in the original repository by the user.

## Recommended original-repository verification

```text
Debug x64 build
Release x64 build
Debug engine launch with matching Debug DLL
Release engine launch with matching Release DLL
Debug engine + Release DLL mismatch rejection
Missing DLL startup failure without stale loaded records
Missing GetRendererModuleApi startup failure with reference rollback
Repeated ModuleBinding Bind on the same object does not increase references
Two bindings Acquire the same module; first Release keeps DLL loaded; final Release unloads
Descriptor implementation change while acquired rejects a new Acquire
Release old binding, then Acquire loads the changed binary
```
