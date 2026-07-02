---
Review-ID: 2026-07-02_VulkanLinuxRenderer
Author: Claude
Baseline: 2026-07-02T13:26 sync | commit=unknown Source=93
Session-Id:
Status: Cross-reviewed
---
# Claude REVIEW — 2026-07-02_VulkanLinuxRenderer

## 1. 독립 초기판단

# 1. 독립 초기판단

## 판단 범위와 근거 한계

이번 판단은 제공된 `README.md`, `Common/SHARED_RULES.md`, `Projects/CyphenEngine/RULES.md` 텍스트만을 근거로 한다. `Projects/CyphenEngine/baseline/CyphenEngine/DevLog/폴더 기능 정리.txt`, `Todos.txt`, 실제 `CyphenRendererVulkan` 모듈 소스, `Source/Platform/Windows` Vulkan HAL 구현은 이 대화에 직접 인용되지 않았으므로, 아래 결론은 "베이스라인 아키텍처 원칙으로부터의 추론"이며 "현재 소스 확인"이 아니다. 이 구분은 evidence 단계에서 반드시 재확인되어야 한다.

## 핵심 질문별 독립 판단

### Q1. `.so` 를 기존 Renderer Module ABI / 산출물 레이아웃에 어떻게 연결할 것인가

- 레이어 구조상 (`Build / Core / HAL / Platform / Engine / Runtime / Editor / Modules / pch`) RendererVulkan은 `Modules` 레이어 소속이고, OS별 HAL 세부구현은 `Platform/*` 소속이라는 분리가 이미 File/Path/Time/Logger 패턴으로 확립되어 있다. Linux `.so`도 이 패턴을 그대로 따라야 하며, 별도의 "Linux 전용 모듈 로더 규약"을 새로 만들 필요는 없다.
- Windows `.dll`과 동일한 모듈 진입점 계약(entry point signature, ABI)을 유지하고, 산출물 배치 경로만 OS 조건부로 나누는 것이 맞다. 새로운 discovery/추상화 계층을 추가하는 것은 "Skull 프로젝트 stream-container 과설계 반복 금지" 규칙에 정면으로 위배될 위험이 크다.
- `export visibility 주입`은 별도 이슈다. Windows는 `__declspec(dllexport/import)` 매크로로 처리되고 있을 것이므로, 동일한 `CYPHEN_API` 매크로 계열에 GCC/Clang `__attribute__((visibility("default")))` 분기를 추가하고, 기본 visibility는 `-fvisibility=hidden`으로 좁혀 모듈 경계를 명시적으로 유지해야 한다. 이 부분은 Build 레이어가 주입하는 "platform and string policy" 책임 범위에 정확히 들어맞는다.

### Q2. Window / Surface 생성 책임을 Launch / Platform-Linux / RendererVulkan HAL 중 어디에 둘 것인가

- `Core must not call OS APIs directly`, `Platform-specific implementations ... belong under Source/Platform/*` 규칙은 File/Path/Time/Logger에만 국한된 서술이지만, Window/Surface도 동일한 "OS 자원 소유"라는 점에서 같은 원칙을 적용하는 것이 자연스럽다.
- 그러나 Vulkan surface 생성(`vkCreateXcbSurfaceKHR` / `vkCreateWaylandSurfaceKHR`)은 native window handle뿐 아니라 Vulkan instance extension 선택(`VK_KHR_xcb_surface` vs `VK_KHR_wayland_surface`)과 강하게 결합되어 있어, 순수하게 Platform/Linux에만 둘 수도 없다.
- 독립 판단: **Platform/Linux가 window 생성 + native handle 획득 + event pump를 소유**하고, **RendererVulkan 내부 Vulkan HAL이 그 native handle을 받아 `vkCreate*SurfaceKHR` 호출만 담당**하는 이중 분리가 옳다. Launch/Runtime은 두 계층을 연결하는 배선(wiring)만 담당한다. RendererVulkan `.so`가 X11 display 연결이나 window 자체를 직접 만드는 설계는 Platform 소유권 위반으로 간주해야 한다.

### Q3. X11/Wayland 의존성을 기본 Linux 실행 경로에 고정하지 않으면서 windowed first-light를 검증하는 방법

- 범위에 headless/server 실행 분리가 명시되어 있으므로, 기본 Linux 빌드/실행 경로는 X11/Wayland 클라이언트 라이브러리 링크 없이 성립해야 한다.
- RendererVulkan 모듈은 surface-optional init API(native handle이 없으면 headless device/instance만 생성)를 갖춰야 하고, X11/Wayland 링크는 windowed 옵션이 켜진 빌드에서만 발생해야 한다.
- first-light 검증은 X11 하나만 먼저 선택해 최소 별도 실행 바이너리로 검증하고, Wayland는 이번 패치 범위에서 명시적으로 제외/후속 과제로 남기는 것이 "small reviewable patch plan" 작업 순서 원칙에 부합한다. 두 백엔드를 동시에 처리하려는 시도는 이번 단계에서 위험도가 높다.

### Q4. headless/server 실행과 windowed 실행을 빌드/실행 설정에서 어떻게 분리할 것인가

- 빌드 타임: windowed 지원 여부를 컴파일 옵션/타겟 분리로 제어해 headless 빌드에는 X11/Wayland 링크가 아예 포함되지 않게 한다.
- 런타임: Launch 레이어가 설정/인자에 따라 window 생성 여부를 결정하고, RendererVulkan init 호출 시 native handle 유무로 windowed/headless 분기를 태운다. 이 분기가 모듈 API 시그니처 차원에서 명시적으로 존재해야 하며, 암묵적 null 체크로 처리하는 것은 계약을 불명확하게 만든다.

## 리스크로 명시할 항목

1. RendererVulkan `.so`가 window 생성/event loop까지 떠안는 설계는 Platform 소유권 위반이자 향후 Wayland/다른 backend 확장 시 재작업 비용을 키운다.
2. Windows/Linux를 아우르는 범용 "Surface 추상화 레이어"를 이번 패치에서 미리 만드는 것은 Skull 과설계 재발 위험이 있다. 지금은 OS별 native handle struct를 renderer init에 넘기는 최소 계약으로 충분하다.
3. Export visibility 매크로 확장 없이 진행하면 Linux `.so`가 필요 이상 심볼을 노출하거나 반대로 entry point가 숨겨져 모듈 로더가 실패할 수 있다 — 이번 패치의 필수 항목으로 다뤄야 한다.
4. Wayland 지연 결정은 DevLog `Todos.txt`에 명시적으로 남겨야 하며, 암묵적으로 빠뜨리면 안 된다.

Position: KEEP

## 2. 교차검증

## 2. 교차검증

### 2.1 독립 판단 (비교 기준)

Codex의 답변을 읽기 전 형성한 내 자신의 판단은 다음과 같다. #3_4는 "ABI 배선(wiring)"과 "실제 windowed first-light 검증"을 분리해서 다뤄야 한다. `CyphenRendererVulkan.so` 빌드/배치/export visibility는 기존 `RendererModuleApi` 계약을 건드리지 않는 순수 빌드 시스템 작업이므로 우선순위가 높고 위험이 낮다. 반면 Linux surface 생성은 실제 코드가 필요한 기능 작업이며, 이것이 완성되기 전까지는 "Linux 렌더러 연결"이 검증되었다고 말할 수 없다. 또한 최상위 `CMakeLists.txt`에서 `find_package(X11 REQUIRED)`로 X11을 무조건 요구하는 구조는, 헤드리스/서버 실행 경로에도 X11 의존성을 강제로 얹는 경계 위반 소지가 있어 이번 검토에서 반드시 지적해야 할 지점이라고 판단했다.

### 2.2 Codex 판단과의 비교

대체로 일치한다.

- 우선순위(작은 패치 먼저, window/surface 소유권 재설계는 다음 단계)는 project rule의 "work order: structure summary -> small reviewable patch plan -> small change"와 "Do not start with large rewrites"에 부합하며 내 판단과 같다.
- `ModuleLoader::Load`의 `dlopen` 계약, `GetRendererModuleApi` export 필요성, `.so` 산출물 배치를 1차 목표로 삼은 것은 타당하다.
  - `Projects/CyphenEngine/baseline/CyphenEngine/Source/Platform/Linux/Private/ModuleLoader.cpp : ModuleLoader::Load`
  - `Projects/CyphenEngine/baseline/Modules/Renderer/CyphenRendererVulkan/Source/Private/VulkanRendererModule.cpp : GetRendererModuleApi`
- `CMakeLists.txt : find_package(X11 REQUIRED)`를 boundary 긴장 지점으로 지목한 것은 내 독립 판단과 정확히 겹친다. 이는 project rule "Do not expose unrestricted raw IO to runtime user code"와 직접 대응하지는 않지만, `DevLog/Todos.txt`가 명시한 "X11/Wayland를 기본 실행 조건으로 고정하지 말라"는 지침과 baseline 코드가 실제로 충돌한다는 점을 정확히 짚었다.
- Vulkan 모듈 내부 `Source/Platform/Linux` 아래에 surface HAL을 두고 Engine/Core/Platform 공통층에는 올리지 않는다는 layering 판단도, "Core must not call OS APIs directly"와 "Platform-specific implementations... belong under Source/Platform/*"라는 baseline 원칙을 module 레벨로 정확히 확장 적용한 것으로 보인다. 이는 `CyphenEngine/Source/Platform/Linux`(엔진 레벨 HAL)와 `Modules/Renderer/CyphenRendererVulkan/Source/Platform/Linux`(모듈 레벨 HAL)를 구분한 것으로, "Do not repeat old Skull project stream-container overengineering pattern" 회피 방향과도 맞는 합리적 구분이다.

이견 및 보강이 필요한 지점:

1. Codex는 "Linux export macro를 정리해 `GetRendererModuleApi`를 `dlsym` 가능하게 만든다"고만 서술하고, 실제 export macro 정의 파일(`__attribute__((visibility("default")))` 또는 이에 준하는 매크로가 정의된 위치)을 인용하지 않았다. Windows `__declspec(dllexport)`와 대응되는 Linux 매크로가 baseline에 이미 존재하는지, 존재한다면 어디인지 근거가 빠져 있다. evidence 단계에서 반드시 확인이 필요하다.
2. `.so` 산출물 배치 경로로 `BuildArtifacts/Binaries/Linux/<Arch>/<Config>/` 계열을 언급했으나, 이는 Windows 산출물 레이아웃과의 유비로 보이며 Linux CMake 빌드 스크립트 안에 동일 규칙이 실제로 존재하는지 직접 인용된 근거가 없다. 확인 필요.
3. "빌드 옵션 또는 실행 설정의 분기점을 남겨야 한다"는 headless/windowed 분리 권고는 방향은 맞지만 구체적 메커니즘(CMake option 이름, 런타임 플래그 등)이 제시되지 않아 다소 추상적이다. `DevLog/Todos.txt`에 이미 구체적 항목(예: Runtime Config 관련 TODO)이 있다면 그것을 직접 인용해 제안을 좁혀야 한다.
4. Linux `Surface.cpp`의 결함(`VK_USE_PLATFORM_UXIX_KHR` 오타, 시그니처 불일치, 빈 반환)은 Codex가 구체적으로 지적한 강한 근거이며, 이는 "windowed renderer first-light" 목표가 현재 baseline에서 아직 달성되지 않았다는 내 독립 판단과 정확히 일치한다. 이 부분은 실제 파일 상태 확인이 되면 이번 검토의 핵심 리스크로 격상해야 한다.

전체적으로 Codex의 결론(우선순위, 패치 순서, boundary 판단)에 대해 실질적 반박 지점은 없고, 근거 보강이 필요한 세부 사항만 존재한다.

Verdict: AGREE
