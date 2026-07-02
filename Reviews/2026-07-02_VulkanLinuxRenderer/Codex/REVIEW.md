---
Review-ID: 2026-07-02_VulkanLinuxRenderer
Author: Codex
Baseline: 2026-07-02T13:26 sync | commit=unknown Source=93
Session-Id:
Status: Initial
---
# Codex REVIEW — 2026-07-02_VulkanLinuxRenderer

## 1. 독립 초기판단

판단: #3_4의 우선순위는 Linux용 `CyphenRendererVulkan.so`를 기존 Renderer Module ABI와 산출물 규격에 붙이는 작은 패치가 먼저이고, window/surface 소유권 재설계는 그 다음 단계로 미뤄야 합니다. 현재 baseline은 Renderer ABI와 Vulkan 모듈 내부 HAL 방향을 이미 갖고 있지만, Linux 모듈 빌드 타깃, export visibility, 실제 surface 구현, 실행파일과 모듈 산출물 배치가 아직 한 줄로 연결되어 있지 않습니다.

근거:
- `Projects/CyphenEngine/baseline/CyphenEngine/Source/Modules/Renderer/Public/RendererModule.h : RendererModuleApi`
- `Projects/CyphenEngine/baseline/CyphenEngine/Source/Modules/Renderer/Private/Renderer.cpp : Renderer::Initialize`
- `Projects/CyphenEngine/baseline/CyphenEngine/Source/Platform/Linux/Private/ModuleLoader.cpp : ModuleLoader::Load`
- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/Private/VulkanRendererModule.cpp : GetRendererModuleApi`
- `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/2026/26.07.01.txt : 다음 작업` (DevLog date: 2026-07-01)

구체적으로 Linux `ModuleLoader::Load`는 `CyphenRendererVulkan.so`라는 이름을 `dlopen`하는 계약을 이미 갖고 있습니다. 따라서 #3_4의 1차 성공 조건은 `CyphenRendererVulkan.so`가 그 이름으로, 실행파일이 찾을 수 있는 `BuildArtifacts/Binaries/Linux/<Arch>/<Config>/` 계열 위치에 생성되고, `GetRendererModuleApi`가 Linux에서 `dlsym` 가능한 visibility로 export되는 것입니다. 이 부분은 기존 ABI를 바꾸지 않고 해결해야 합니다.

현재 Linux window/surface 경계는 아직 확정된 설계라기보다 검증용 연결에 가깝습니다. `Linux Launch`는 X11 window를 만들고 `LaunchContext.windowInfo`에 handle/size를 넣으며, `CyphenRendererVulkan`을 강제로 활성화합니다. 반면 project TODO는 Linux에서 X11/Wayland를 기본 실행 조건으로 고정하지 말고 windowed target 또는 renderer 출력 경로의 선택 의존성으로 관리하라고 적고 있습니다. 이 긴장은 실제로 baseline에 존재합니다.
- `Projects/CyphenEngine/baseline/CyphenEngine/Source/Platform/Linux/Private/Launch.cpp : Launch::CreateLaunchContext`
- `Projects/CyphenEngine/baseline/CyphenEngine/CMakeLists.txt : find_package(X11 REQUIRED)`
- `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/Todos.txt : Renderer / Linux Porting / Build Target / Runtime Config`

따라서 이번 단계에서 Launch를 곧바로 “영구 WindowSystem”으로 확정하면 안 됩니다. X11 Launch는 Linux first-light용 windowed entry로 제한하고, headless/server 실행과 windowed renderer 실행을 분리할 수 있도록 빌드 옵션 또는 실행 설정의 분기점을 남겨야 합니다. 다만 지금 당장 Wayland 추상화나 완전한 WindowSystem을 새로 만드는 것은 범위 초과입니다.

또 하나의 강한 위험은 Vulkan Linux surface 구현이 baseline상 완성되어 있지 않다는 점입니다. Linux `Surface.cpp`는 `VK_USE_PLATFORM_UXIX_KHR` 오타, 헤더와 맞지 않는 `CreateVulkanSurface` 시그니처, 반환 없는 빈 함수 상태입니다. 반대로 `Surface.h`와 Windows 구현은 “Vulkan 모듈 내부 HAL / Platform seam” 방향을 이미 제시합니다. 그러므로 #3_4에서는 Linux surface를 그 내부 seam에 맞춰 최소 구현해야 하며, Engine/Core/Platform 공통층에 Vulkan/X11 세부를 올리면 안 됩니다.
- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/HAL/Private/Surface.h : CreateVulkanSurface`
- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/Platform/Linux/Private/Surface.cpp : CreateVulkanSurface`
- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/Private/VulkanRenderer.cpp : VulkanRenderer::CreateSurface`
- `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/2026/26.07.01.txt : 정리한 설계 기준` (DevLog date: 2026-07-01)

결론적으로 권장 패치 순서는 다음입니다. 먼저 `CyphenRendererVulkan.so` CMake 타깃과 산출물 배치를 추가합니다. 그 다음 Linux export macro를 정리해 `GetRendererModuleApi`를 `dlsym` 가능하게 만듭니다. 그 다음 Vulkan 모듈 내부의 Linux `Surface.cpp`를 Xlib surface 기준으로 최소 완성합니다. 마지막으로 X11 의존성이 기본 Linux/headless 실행 경로에 영구 고정되지 않도록 `windowed renderer first-light` 범위임을 빌드/런타임 경계에 남깁니다.

Position: KEEP
