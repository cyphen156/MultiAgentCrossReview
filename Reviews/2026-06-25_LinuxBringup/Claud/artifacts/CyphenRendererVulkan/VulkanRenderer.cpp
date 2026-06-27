#include "VulkanRenderer.h"

// ============================================================================
// #3_1 스캐폴드: 미구현 스텁.
// 실제 Vulkan 구현은 #3_2(Windows first-light)에서 채웁니다.
// 현재는 모듈이 빌드·로드되고 RendererType::Vulkan으로 인식되는지까지만
// 검증합니다. Initialize가 false를 반환하므로 createRenderer는 의도적으로
// 실패합니다("모듈 로드 OK, 백엔드 미구현").
// ============================================================================

bool VulkanRenderer::Initialize(const NativeWindowInfo& windowInfo)
{
	(void)windowInfo;
	return false;
}

void VulkanRenderer::Shutdown()
{
}

bool VulkanRenderer::ExecuteCommandList(const RenderCommandList& commandList)
{
	(void)commandList;
	return false;
}

#ifdef _DEBUG
bool VulkanRenderer::ExecuteResourceCommandList(const ResourceCommandList& commandList)
{
	(void)commandList;
	return false;
}
#endif
