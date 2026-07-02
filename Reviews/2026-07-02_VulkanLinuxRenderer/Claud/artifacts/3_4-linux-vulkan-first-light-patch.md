# #3_4 Linux Vulkan First-Light — 전체 패치 확정본

Review-ID: 2026-07-02_VulkanLinuxRenderer
Author: Claude (candidate patch)
Baseline: 2026-07-02T13:26 sync
Scope: Editor/Game **windowed** Vulkan first-light on Linux. **포팅 완료 아님.**

> 이 문서는 대화 없이도 적용 가능한 자립 패치 명세다. 원본 repo 적용은 사용자가 수행한다.

---

## 확정 규약 (반영 결론)

- `_WIN32` **사용 금지** → `Build/Public/PlatformDefine.h`의 `PLATFORM_WINDOWS` / `PLATFORM_LINUX` (0/1 매크로) 사용.
- `Build::Is*Build`(constexpr, `BuildInfo.h`)는 **`if constexpr` 코드 분기 전용**. 전처리기 결정(export 속성, `#define VK_USE_PLATFORM_*`, include 분기)에는 못 씀 → `PLATFORM_*` 매크로.
- export 매크로는 공용 `Modules/Public/ModuleExport.h` **한 곳**. `extern "C"`는 매크로에 넣지 않고 사용부에 명시(`extern "C" CYPHEN_MODULE_EXPORT`) — 링크 규약과 visibility 분리.
- 모듈 CMake는 `TARGET_PLATFORM_*`(→ PlatformDefine.h)와 `BUILD_TARGET_*`(→ BuildInfo.h)를 **반드시 주입**.
- `dlopen("CyphenRendererVulkan.so")`는 bare-name → exe 옆 자동 탐색 안 됨. `$ORIGIN` rpath로 해결.
- `add_library(SHARED)` Linux 기본 `lib` 접두 → `PREFIX ""`로 제거(ModuleLoader가 `CyphenRendererVulkan.so`를 찾음).
- X11은 이번 패치에서 windowed 전제(빌드/링크 유지). Server의 X11 build/link 분리는 후속.
- `XInitThreads()` 유지.

---

## 패치 순서 (작은 단위 2개)

- **P1 — 빌드 인프라 (동작 불변 리팩터).** cmake 헬퍼 + 루트 CMake + ModuleExport.h + 엔진 CMake 산출물 블록 치환. 검증: 엔진이 이전과 동일 산출물로 빌드.
- **P2 — RendererVulkan .so first-light (P1 위에).** 모듈 CMake + Surface HAL + NativeWindowInfo + Launch + export 교체 + rpath. 검증: dlopen/dlsym + `vkCreateXlibSurfaceKHR == VK_SUCCESS`.

후속(#3_4 아님): Server X11 build/link 분리 · 이벤트 시스템 추출 · Wayland · input/resize 라우팅.

---

# P1 — 빌드 인프라

## P1-1 `cmake/CyphenTarget.cmake` (신규, 공유 규칙 SSOT — MSVC의 CyphenBuild.props 대응)

```cmake
include_guard(GLOBAL)

set(CYPHEN_ARTIFACTS_ROOT ${CMAKE_CURRENT_LIST_DIR}/../BuildArtifacts CACHE INTERNAL "")
set(CYPHEN_ENGINE_SOURCE  ${CMAKE_CURRENT_LIST_DIR}/../CyphenEngine/Source CACHE INTERNAL "")

# 산출물: BuildArtifacts/Binaries/<Platform>/<Arch>/<Config>/ (엔진·모든 모듈 공통)
function(cyphen_set_output_dirs target)
    if(WIN32)      ; set(_p Windows)
    elseif(UNIX)   ; set(_p Linux)
    else()         ; message(FATAL_ERROR "Unsupported platform.") ; endif()
    if(CMAKE_SIZEOF_VOID_P EQUAL 8) ; set(_a x64) ; else() ; set(_a x86) ; endif()
    set(_bin ${CYPHEN_ARTIFACTS_ROOT}/Binaries/${_p}/${_a})
    foreach(cfg IN ITEMS Debug Release RelWithDebInfo MinSizeRel)
        string(TOUPPER ${cfg} U)
        set_target_properties(${target} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY_${U} ${_bin}/${cfg}
            LIBRARY_OUTPUT_DIRECTORY_${U} ${_bin}/${cfg}
            ARCHIVE_OUTPUT_DIRECTORY_${U} ${_bin}/${cfg})
    endforeach()
endfunction()

# 공통 컴파일 정책 (std17 / 경고 / TARGET_PLATFORM_* 주입 → PlatformDefine.h 성립)
function(cyphen_apply_common target)
    target_compile_features(${target} PRIVATE cxx_std_17)
    set_target_properties(${target} PROPERTIES CXX_EXTENSIONS OFF)
    target_compile_definitions(${target} PRIVATE
        $<$<BOOL:${WIN32}>:TARGET_PLATFORM_WINDOWS>
        $<$<BOOL:${UNIX}>:TARGET_PLATFORM_LINUX>)
    target_compile_options(${target} PRIVATE
        $<$<CXX_COMPILER_ID:MSVC>:/utf-8;/permissive-;/W3>
        $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-Wall;-Wextra>)
endfunction()

# 런타임 모듈(.so/.dll): dlopen 이름규칙(PREFIX 제거) + 산출물 + visibility + 엔진헤더
function(cyphen_add_module name)
    cmake_parse_arguments(ARG "" "" "SOURCES;INCLUDE;LINK" ${ARGN})
    add_library(${name} SHARED ${ARG_SOURCES})
    set_target_properties(${name} PROPERTIES PREFIX "" OUTPUT_NAME "${name}")
    cyphen_apply_common(${name})
    cyphen_set_output_dirs(${name})
    target_include_directories(${name} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Source ${CYPHEN_ENGINE_SOURCE} ${ARG_INCLUDE})
    target_compile_options(${name} PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-fvisibility=hidden>)
    if(ARG_LINK) ; target_link_libraries(${name} PRIVATE ${ARG_LINK}) ; endif()
endfunction()
```

## P1-2 루트 `CMakeLists.txt` (신규, repo 루트 — 헬퍼 발견 + 엔진↔모듈 동시 빌드)

```cmake
cmake_minimum_required(VERSION 3.20)
project(Cyphen LANGUAGES CXX)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)
add_subdirectory(CyphenEngine)
add_subdirectory(Modules/Renderer/CyphenRendererVulkan)
```

## P1-3 `CyphenEngine/Source/Modules/Public/ModuleExport.h` (신규, export 매크로 SSOT)

```cpp
#pragma once

#include "Build/Public/PlatformDefine.h"

#if PLATFORM_WINDOWS
#define CYPHEN_MODULE_EXPORT __declspec(dllexport)
#elif PLATFORM_LINUX
#define CYPHEN_MODULE_EXPORT __attribute__((visibility("default")))
#else
#define CYPHEN_MODULE_EXPORT
#endif
```

## P1-4 `CyphenEngine/CMakeLists.txt` (산출물 블록 치환 + rpath)

- 상단에 `include(CyphenTarget)` (루트에서 add_subdirectory되므로 CMAKE_MODULE_PATH 유효).
- 기존 산출물 정규화 블록(현재 line 127~161)을 아래로 치환:

```cmake
cyphen_set_output_dirs(CyphenEngine)
```

- dlopen bare-name이 exe 옆을 탐색하도록 rpath 추가:

```cmake
if(UNIX)
    set_target_properties(CyphenEngine PROPERTIES
        BUILD_RPATH "$ORIGIN" INSTALL_RPATH "$ORIGIN")
endif()
```

> `cyphen_apply_common(CyphenEngine)`로 std/경고/TARGET_PLATFORM_* 정의도 치환 가능하나, 엔진 고유 정의(BUILD_TARGET_EDITOR, _WINDOWS, UNICODE 등)와 충돌하지 않게 최소 치환만 권장. P1은 "동작 불변"이 검증 기준.

---

# P2 — RendererVulkan .so first-light

## P2-1 `Modules/Renderer/CyphenRendererVulkan/CMakeLists.txt` (신규)

```cmake
cmake_minimum_required(VERSION 3.20)
project(CyphenRendererVulkan LANGUAGES CXX)
include(CyphenTarget)

find_package(Vulkan REQUIRED)
set(SOURCES
    Source/Private/VulkanRenderer.cpp
    Source/Private/VulkanRendererModule.cpp)

if(UNIX)
    find_package(X11 REQUIRED)
    list(APPEND SOURCES Source/Platform/Linux/Private/Surface.cpp)
    set(PLAT_INC ${X11_INCLUDE_DIR})
    set(PLAT_LINK ${X11_LIBRARIES})
elseif(WIN32)
    list(APPEND SOURCES Source/Platform/Windows/Private/Surface.cpp)
endif()

cyphen_add_module(CyphenRendererVulkan
    SOURCES ${SOURCES}
    INCLUDE ${PLAT_INC}
    LINK    Vulkan::Vulkan ${PLAT_LINK})

# BuildInfo.h(모듈 코드가 Build:: 참조 시)용 — 엔진과 동일 build target 주입
target_compile_definitions(CyphenRendererVulkan PRIVATE BUILD_TARGET_EDITOR)
```

> `PREFIX ""`, 산출물 경로, `-fvisibility=hidden`, `TARGET_PLATFORM_*`, 엔진 include는 헬퍼가 흡수. 남는 건 모듈 고유(소스 + Vulkan/X11 의존 + build target)뿐.

## P2-2 `Source/Private/VulkanRendererModule.cpp` (export 교체)

기존 `extern "C" __declspec(dllexport)`(현재 line 96)를 교체. 상단 include 추가:

```cpp
#include "Modules/Public/ModuleExport.h"
```

선언부:

```cpp
extern "C" CYPHEN_MODULE_EXPORT
RendererModuleResult GetRendererModuleApi(RendererModuleApi* outRendererModuleApi)
{
    // (본문 기존과 동일)
}
```

## P2-3 `CyphenEngine/Source/HAL/Public/NativeWindowInfo.h` (필드 1개 추가)

```cpp
struct NativeWindowInfo
{
    void* nativeWindowHandle = nullptr;
    void* nativeDisplayHandle = nullptr;  // Linux: X11 Display*(비소유). Windows: 미사용.
    uint32 windowWidth = 0;
    uint32 windowHeight = 0;
};
```

주석의 "Window Handle만 전달" → "Window/Display handle 전달(비소유)"로 갱신.

## P2-4 `Modules/.../Source/Platform/Linux/Private/Surface.cpp` (전체 구현)

```cpp
#define VK_USE_PLATFORM_XLIB_KHR

#include <vulkan/vulkan.h>

#include <X11/Xlib.h>

#include <cstdint>

#include "HAL/Private/Surface.h"

const char* GetVulkanPlatformSurfaceExtensionName()
{
    return VK_KHR_XLIB_SURFACE_EXTENSION_NAME;
}

bool CreateVulkanSurface(
    VkInstance instance,
    const NativeWindowInfo& windowInfo,
    VkSurfaceKHR* outSurface)
{
    if (instance == VK_NULL_HANDLE ||
        windowInfo.nativeDisplayHandle == nullptr ||
        windowInfo.nativeWindowHandle == nullptr ||
        outSurface == nullptr)
    {
        return false;
    }

    Display* const display =
        static_cast<Display*>(windowInfo.nativeDisplayHandle);

    const Window window =
        static_cast<Window>(
            reinterpret_cast<std::uintptr_t>(windowInfo.nativeWindowHandle));

    VkXlibSurfaceCreateInfoKHR surfaceCreateInfo = {};
    surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR;
    surfaceCreateInfo.dpy = display;
    surfaceCreateInfo.window = window;

    return vkCreateXlibSurfaceKHR(
        instance,
        &surfaceCreateInfo,
        nullptr,
        outSurface) == VK_SUCCESS;
}
```

해소된 결함: 오타 `UXIX→XLIB`, 시그니처 `&→*`(헤더 일치), 빈 본문, `GetVulkanPlatformSurfaceExtensionName()` 누락. Windows 구현과 대칭.

## P2-5 `CyphenEngine/Source/Platform/Linux/Private/Launch.cpp`

상단 include 추가:

```cpp
#include "Build/Public/BuildInfo.h"
```

`CreateLaunchContext`에 Display 전달 한 줄 추가(nativeWindowHandle 설정 직후):

```cpp
launchContext.windowInfo.nativeDisplayHandle = g_display;
```

`main()`을 build target으로 분기(Server는 X11 심볼 일절 미접촉 — poll은 종료 파이프 1개만):

```cpp
int main(int argc, char** argv)
{
    (void)argc; (void)argv;

    if constexpr (Build::IsServerBuild)
    {
        LaunchContext launchContext;   // windowInfo 비움 + renderer descriptor 없음

        if (Launch::StartEngineThread(launchContext) == false)
        {
            ModuleManager::Shutdown();
            return EXIT_FAILURE;
        }

        pollfd waitHandle = {};
        waitHandle.fd = Launch::engineThreadExitPipe[0];
        waitHandle.events = POLLIN;

        for (;;)
        {
            const int waitResult = ::poll(&waitHandle, 1, -1);
            if (waitResult < 0)
            {
                if (errno == EINTR) { continue; }
                Launch::RequestEngineShutdown();
                break;
            }
            if ((waitHandle.revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL)) != 0) { break; }
        }

        Launch::JoinEngineThread();
        return EXIT_SUCCESS;
    }
    else
    {
        if (MyRegisterClass() == false) { return EXIT_FAILURE; }

        g_hMainWindow = InitInstance(1);
        if (g_hMainWindow == 0) { DestroyInstance(); return EXIT_FAILURE; }

#ifdef _DEBUG
        RunCoreIoTests();
#endif
        const LaunchContext launchContext = Launch::CreateLaunchContext(g_hMainWindow);

        if (Launch::StartEngineThread(launchContext) == false)
        {
            ModuleManager::Shutdown(); DestroyInstance(); return EXIT_FAILURE;
        }
#ifdef _DEBUG
        RunModuleTests();
#endif
        const int x11ConnectionHandle = ConnectionNumber(g_display);
        const int engineThreadExitHandle = Launch::engineThreadExitPipe[0];

        // ... 기존 while 루프(XPending/XNextEvent/WndProc/poll 2-fd) 그대로 ...

        Launch::JoinEngineThread();
        DestroyInstance();
        return EXIT_SUCCESS;
    }
}
```

> **한계 명시:** 비-템플릿 `main()`이라 `if constexpr` 두 분기가 모두 컴파일된다. 즉 이 단일파일 방식은 **런타임만 가드**하고 Server 빌드도 여전히 `<X11/Xlib.h>`/X11 링크를 요구한다. 진짜 X11-free Server는 소스 분리(`LaunchLinuxServer.cpp`)로 승격 — #3_4 제외.

---

## 빌드/검증 (WSL2)

```bash
cd /mnt/c/Project/CyphenEngine
cmake -S . -B BuildArtifacts/Intermediate/Linux/x64/Debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build BuildArtifacts/Intermediate/Linux/x64/Debug
ls BuildArtifacts/Binaries/Linux/x64/Debug/     # CyphenEngine, CyphenRendererVulkan.so (lib 접두 없음)
./BuildArtifacts/Binaries/Linux/x64/Debug/CyphenEngine
```

성공 판정: X11 창 + `dlopen`/`dlsym`(`GetRendererModuleApi`) 성공 + `vkCreateXlibSurfaceKHR == VK_SUCCESS`.

---

## 미검증 전제 (솔직히)

1. `VulkanRenderer.cpp` 미확인 — 모듈 CMake 소스 목록/추가 링크(예: 셰이더 SPIR-V, 추가 시스템 lib)와 first-light가 surface 생성까지인지 swapchain/present까지인지는 이 파일에 달림.
2. `BuildInfo.h`의 `Build::` 참조가 모듈 코드에 실제로 있는지 미확인 — 없으면 P2-1의 `BUILD_TARGET_EDITOR` 주입은 방어적(무해).
3. P1-4 엔진 CMake 치환은 "동작 불변" 검증 필수 — 기존 산출물 경로/정의와 1:1 대응 확인.
