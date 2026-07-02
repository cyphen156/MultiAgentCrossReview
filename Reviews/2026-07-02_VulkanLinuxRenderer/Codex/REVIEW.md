---
Review-ID: 2026-07-02_VulkanLinuxRenderer
Author: Codex
Baseline: 2026-07-02T13:26 sync | commit=unknown Source=93
Session-Id:
Status: Cross-reviewed
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

## 2. 교차검증

Claude의 판단에는 대체로 동의합니다. 특히 RendererVulkan `.so`가 window/event loop를 자체 소유하지 않아야 한다는 점, Linux surface/window 책임을 Platform/Linux와 RendererVulkan 내부 HAL 사이에서 먼저 정리해야 한다는 점, X11은 first-light 검증 경로로 두되 Wayland와 headless 경계를 TODO로 남겨야 한다는 점은 기준선과 맞습니다.

다만 Claude 리뷰는 구현 가능성 측면에서 한 가지 더 강하게 지적했어야 합니다. 기준선의 Linux Vulkan surface 구현은 단순 미완성이 아니라 현재 형태로는 계약 불일치입니다. `Surface.h`는 `VkSurfaceKHR* outSurface`를 받는 `CreateVulkanSurface`를 선언하지만, Linux `Surface.cpp`는 `VkSurfaceKHR& outSurface` 시그니처를 정의하고 함수 본문도 비어 있습니다. 또한 `GetVulkanPlatformSurfaceExtensionName()` Linux 구현이 없고, `VK_USE_PLATFORM_UXIX_KHR` 오타도 보입니다. 즉 #3_4의 첫 패치는 아키텍처 판단 이전에 "Linux Vulkan module이 컴파일 가능한 최소 HAL 계약을 만족하는가"를 포함해야 합니다.

Claude가 언급한 `find_package(X11 REQUIRED)` 우려도 타당합니다. 현재 `CyphenEngine` CMake는 UNIX에서 X11을 필수로 요구하므로, DevLog/Todos의 "Linux는 GUI가 기본 실행 조건이 아니다"라는 방향과 충돌할 수 있습니다. 다만 이것은 RendererVulkan `.so` 자체의 CMake가 아직 기준선에 보이지 않는 상태이므로, 즉시 결론은 "X11을 renderer/windowed target 선택 의존성으로 옮길 설계가 필요하다" 정도가 적절합니다.

Verdict: AGREE

## 2. 교차검증

### 독립 판단

#3_4의 1차 목표는 Linux에서 `CyphenRendererVulkan.so`를 기존 Renderer Module ABI에 연결하고, 산출물 배치와 export visibility를 먼저 닫는 것입니다. 현재 baseline은 Linux `ModuleLoader`가 `moduleName + ".so"`를 `dlopen`하고 `dlsym`으로 심볼을 찾는 계약을 이미 갖고 있으므로, 새 모듈 discovery 규약을 만들기보다 `GetRendererModuleApi`가 Linux에서도 같은 이름으로 노출되게 만드는 쪽이 작고 검증 가능한 패치입니다.

Linux surface/window 경계는 별도 리스크로 분리해야 합니다. `NativeWindowInfo`는 Platform Launch가 생성한 native window 전달 구조로 기록되어 있고, Vulkan 모듈 내부 `Surface` HAL은 `NativeWindowInfo`를 `VkSurfaceKHR`로 변환하는 책임을 갖습니다. 따라서 기본 방향은 Launch/Platform이 window와 event loop를 만들고, RendererVulkan module 내부 Platform 구현이 Vulkan surface 생성만 담당하는 구조가 맞습니다.

다만 현재 Linux windowed first-light는 아직 달성된 상태가 아닙니다. Linux `Surface.cpp`는 플랫폼 define 오타, 헤더 시그니처와 다른 out parameter 형태, 빈 구현이 동시에 존재합니다. 또한 최상위 CMake는 UNIX에서 `find_package(X11 REQUIRED)`와 `${X11_LIBRARIES}` 링크를 기본 엔진 타겟에 붙이고 있어, DevLog/Todos가 요구하는 headless/server와 windowed renderer 경계 분리와 긴장 관계가 있습니다.

Position: KEEP

### 교차검증

Claude 판단의 큰 방향에는 동의합니다. 특히 `.so`를 별도 Linux 전용 모듈 규약으로 빼지 않고 기존 Renderer Module ABI에 연결해야 한다는 점, export visibility가 필수 작업이라는 점, Linux window/surface를 RendererVulkan이 통째로 소유하면 Platform 경계를 흐릴 수 있다는 지적은 baseline과 맞습니다.

보강이 필요한 지점은 두 가지입니다. 첫째, “surface-optional init API”는 방향상 이해되지만 현재 `VulkanRendererModule.cpp : CreateRenderer`는 `NativeWindowInfo*`가 null이면 실패하도록 되어 있어, 이번 #3_4의 최소 패치 범위에 바로 넣으면 ABI/런타임 계약 변경이 됩니다. 이 항목은 build/link/export 배선과 분리해 후속 설계 판단으로 남기는 편이 더 안전합니다. 둘째, `.so` 산출물 배치 경로는 최상위 CMake에 공통 `BuildArtifacts/Binaries/<Platform>/<Arch>/<Config>` 규격은 있지만, `CyphenRendererVulkan` 자체가 CMake `add_library` 대상으로 연결된 근거는 확인되지 않았습니다. 따라서 “배치 규칙을 따른다”는 방향은 맞지만 실제 모듈 타겟 추가가 별도 작업으로 필요합니다.

그 외 `find_package(X11 REQUIRED)`를 경계 위반 위험으로 본 점, Linux `Surface.cpp`가 first-light를 막는 구체 결함이라는 점, Wayland를 이번 패치에서 확장하지 않는다는 판단은 모두 동의합니다.

Verdict: AGREE

### 수정 판단

초기 결론은 유지합니다. 다만 #3_4의 권장 순서는 더 좁혀야 합니다.

1. Linux CMake에 `CyphenRendererVulkan` shared library 타겟을 추가하고 기존 binary layout으로 배치합니다.
2. `GetRendererModuleApi` export를 Windows `__declspec(dllexport)` 전용에서 Linux visibility-default까지 포괄하는 명시 매크로로 정리합니다.
3. Linux `ModuleLoader::Load`의 `dlopen`/`dlsym` 계약으로 실제 `.so`와 `GetRendererModuleApi` 탐색을 검증합니다.
4. Linux `Surface.cpp`와 X11/windowed path는 first-light 작업으로 이어가되, headless/server 기본 실행 경로에 X11을 고정하지 않도록 CMake option 또는 windowed target 분리를 별도 판단 대상으로 둡니다.

Position: KEEP

### 근거 확인

- `Projects/CyphenEngine/baseline/CyphenEngine/Source/Platform/Linux/Private/ModuleLoader.cpp : ModuleLoader::Load / ModuleLoader::FindSymbol`  
  Linux 모듈은 `moduleName + ".so"`를 만들고 `dlopen(..., RTLD_NOW | RTLD_LOCAL)`로 로드한 뒤 `dlsym`으로 심볼을 찾습니다.

- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/Private/VulkanRendererModule.cpp : GetRendererModuleApi`  
  현재 export는 `extern "C" __declspec(dllexport)`로 Windows 전용이며, 주석도 Linux `.so` 빌드 시 visibility-default 매크로로 일원화해야 한다고 남겨져 있습니다.

- `Projects/CyphenEngine/baseline/CyphenEngine/CMakeLists.txt : CYPHEN_BINARIES_ROOT / LIBRARY_OUTPUT_DIRECTORY_*`  
  공통 산출물 규격은 `BuildArtifacts/Binaries/<Platform>/<Arch>/<Config>`로 잡혀 있습니다.

- `Projects/CyphenEngine/baseline/CyphenEngine/CMakeLists.txt : find_package(X11 REQUIRED)`  
  UNIX 기본 엔진 타겟이 X11 include/library를 요구하고 링크합니다. 이는 headless/server 기본 실행 경로와 windowed renderer 실행 경로를 분리해야 한다는 DevLog/Todos와 충돌 가능성이 있습니다.

- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/HAL/Private/Surface.h : GetVulkanPlatformSurfaceExtensionName / CreateVulkanSurface`  
  Vulkan 모듈 내부 HAL은 `NativeWindowInfo`를 받아 `VkSurfaceKHR`를 생성하는 계약으로 정리되어 있습니다.

- `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/Platform/Linux/Private/Surface.cpp : CreateVulkanSurface`  
  `VK_USE_PLATFORM_UXIX_KHR` 오타, 헤더와 다른 `VkSurfaceKHR&` 시그니처, 빈 함수 본문이 있어 Linux windowed first-light 근거로는 부족합니다.

- `Projects/CyphenEngine/baseline/CyphenEngine/Source/HAL/Public/NativeWindowInfo.h : NativeWindowInfo`  
  native window 생성자는 Platform Launch이고, Renderer와 renderer 구현 DLL은 소비자로 기록되어 있습니다.

- `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/2026/26.07.01.txt : 다음 작업`  
  DevLog date `2026-07-01`. 다음 작업으로 `CyphenRendererVulkan.so` 빌드/산출물 배치, Linux Vulkan surface 위치, X11 의존성 소유 경계, headless/server와 windowed renderer 빌드 경계 판단이 명시되어 있습니다.

- `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/Todos.txt : Renderer / Linux Porting / Build Target / Runtime Config`  
  Renderer module은 headless 빌드에서 비활성화 가능해야 하고, Linux는 X11/Wayland를 Platform/Linux 기본값으로 고정하지 않으며, 다음 목표가 Linux renderer `.so` 빌드/배치/export 주입임을 확인했습니다.

Evidence-Status: CONFIRMED
