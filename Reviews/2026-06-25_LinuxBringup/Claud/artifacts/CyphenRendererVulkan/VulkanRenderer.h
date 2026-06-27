#pragma once

#include "HAL/Public/NativeWindowInfo.h"
#include "Modules/Renderer/Public/RenderCommand.h"

#ifdef _DEBUG
#include "Modules/Resource/Public/ResourceCommand.h"
#endif

// ============================================================================
// VulkanRenderer
// ----------------------------------------------------------------------------
// Renderer Backend ABI 계약을 Vulkan으로 구현하는 구현체입니다.
//
// #3_1 스캐폴드 단계:
//   - 빌드·로드만 검증합니다. 실제 Vulkan 초기화/그리기는 #3_2에서
//     Windows first-light로 구현합니다.
//   - 모든 메서드는 미구현(false) 스텁입니다.
//
// 책임(구현 예정, #3_2):
//   - Vulkan Instance / Device / Surface / Swapchain 생성
//   - RenderCommand IR 해석
//   - Clear / Present 실행
// ============================================================================

class VulkanRenderer final
{
public:
	VulkanRenderer() = default;
	~VulkanRenderer() = default;

	VulkanRenderer(const VulkanRenderer& other) = delete;
	VulkanRenderer& operator=(const VulkanRenderer& other) = delete;

	VulkanRenderer(VulkanRenderer&& other) = delete;
	VulkanRenderer& operator=(VulkanRenderer&& other) = delete;

	bool Initialize(const NativeWindowInfo& windowInfo);
	void Shutdown();

	bool ExecuteCommandList(const RenderCommandList& commandList);

#ifdef _DEBUG
	bool ExecuteResourceCommandList(const ResourceCommandList& commandList);
#endif
};
