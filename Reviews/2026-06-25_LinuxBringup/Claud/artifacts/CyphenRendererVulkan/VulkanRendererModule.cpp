#include <new>

#include "VulkanRenderer.h"
#include "Modules/Renderer/Public/RendererModule.h"

namespace
{
	RendererModuleResult CreateRenderer(
		const NativeWindowInfo* windowInfo,
		RendererHandle* outRendererHandle)
	{
		if (windowInfo == nullptr ||
			outRendererHandle == nullptr ||
			*outRendererHandle != nullptr)
		{
			return RendererModuleResult::Failure;
		}

		VulkanRenderer* renderer = new (std::nothrow) VulkanRenderer();

		if (renderer == nullptr)
		{
			return RendererModuleResult::Failure;
		}

		if (renderer->Initialize(*windowInfo) == false)
		{
			delete renderer;
			return RendererModuleResult::Failure;
		}

		*outRendererHandle = renderer;

		return RendererModuleResult::Success;
	}

	void DestroyRenderer(RendererHandle rendererHandle)
	{
		VulkanRenderer* renderer = static_cast<VulkanRenderer*>(rendererHandle);

		if (renderer == nullptr)
		{
			return;
		}

		renderer->Shutdown();
		delete renderer;
	}

	RendererModuleResult ExecuteCommandList(
		RendererHandle rendererHandle,
		const RenderCommandList* commandList)
	{
		VulkanRenderer* renderer = static_cast<VulkanRenderer*>(rendererHandle);

		if (renderer == nullptr ||
			commandList == nullptr)
		{
			return RendererModuleResult::Failure;
		}

		if (renderer->ExecuteCommandList(*commandList) == false)
		{
			return RendererModuleResult::Failure;
		}

		return RendererModuleResult::Success;
	}
}

#ifdef _DEBUG
RendererModuleResult ExecuteDebugResourceCommandList(
	RendererHandle rendererHandle,
	const ResourceCommandList* commandList)
{
	VulkanRenderer* renderer = static_cast<VulkanRenderer*>(rendererHandle);

	if (renderer == nullptr ||
		commandList == nullptr)
	{
		return RendererModuleResult::Failure;
	}

	if (renderer->ExecuteResourceCommandList(*commandList) == false)
	{
		return RendererModuleResult::Failure;
	}

	return RendererModuleResult::Success;
}
#endif

// dllexport는 Windows 전용입니다(#3_1 Windows 스캐폴드 기준, Dx11과 동일 유지).
// Linux .so 빌드 시 visibility-default 매크로로 일원화하는 작업은
// ModuleLoader(dlopen) 단계와 묶어 처리합니다(Q001_002 추적 항목).
extern "C" __declspec(dllexport)
RendererModuleResult GetRendererModuleApi(RendererModuleApi* outRendererModuleApi)
{
	if (outRendererModuleApi == nullptr)
	{
		return RendererModuleResult::Failure;
	}

	outRendererModuleApi->apiVersion = RENDERER_MODULE_API_VERSION;
	outRendererModuleApi->rendererType = RendererType::Vulkan;
	outRendererModuleApi->createRenderer = &CreateRenderer;
	outRendererModuleApi->destroyRenderer = &DestroyRenderer;
	outRendererModuleApi->executeCommandList = &ExecuteCommandList;
#ifdef _DEBUG
	outRendererModuleApi->executeDebugResourceCommandList = &ExecuteDebugResourceCommandList;
#endif
	return RendererModuleResult::Success;
}
