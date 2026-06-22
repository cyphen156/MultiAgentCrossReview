Date: 2026-06-22
Question-ID: Q001
Author: Codex
Responds-To: Codex/Q001_005_revision.md
Supersedes: Codex/Q001_005_revision.md
Status: Evidence-Complete
Baseline: 2026-06-22 workspace mirror

# #2_3 implementation static evidence correction

Static contract checking found two defects in `Q001_005_revision.md`:

1. Its free `RemoveModuleRecord` function cannot call private `ModuleLoader::Unload`; only `ModuleManager` is a friend. The helper must be a private `ModuleManager` member.
2. `Launch::StartEngineThread` must not assert on the aggregate `Refresh` result because valid descriptors are intentionally retained when another descriptor is rejected. Required systems decide startup viability through their own initialization.

All files in `Q001_005_revision.md` remain unchanged except for the complete replacements below.

## Corrected replacement — `CyphenEngine/Source/Core/Public/ModuleManager.h`

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

	static bool RemoveModuleRecord(const CString& moduleName);
	static bool UnloadAll();
};
```

## Corrected replacement — `CyphenEngine/Source/Core/Private/ModuleManager.cpp`

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

bool ModuleManager::RemoveModuleRecord(const CString& moduleName)
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

## Corrected function — `Launch::StartEngineThread`

```cpp
bool Launch::StartEngineThread(const LaunchContext& launchContext)
{
	const bool isModuleRefreshSuccessful =
		ModuleManager::Refresh(launchContext.moduleDescriptors);

	(void)isModuleRefreshSuccessful;

	if (engineInstance.InitEngine(launchContext) == false)
	{
		return false;
	}

	engineThread = std::thread(&CyphenEngine::Run, &engineInstance);

	return true;
}
```

# Final static result

With these corrections, no remaining source-level contract conflict was found by static inspection. Build and runtime verification remain prohibited in this read-only mirror and must occur in the original repository.
