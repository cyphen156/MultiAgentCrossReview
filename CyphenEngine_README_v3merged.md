# CyphenEngine

CyphenEngine은 개인 엔진 개발 프로젝트입니다.

목표는 거대한 범용 엔진을 복제하는 것이 아니라, 엔진의 핵심 책임을 직접 설계하고 검증하면서 **DOD(Data-Oriented Design), 모듈식 구조, 빌드 타임 추상화**를 중심으로 한 실행 기반을 만드는 것입니다.

이 프로젝트는 Unity보다는 Unreal 쪽의 저수준 통제와 엔진 중심 철학을 더 강하게 참고하지만, Unreal을 그대로 복제하지는 않습니다. 특히 플랫폼 추상화는 런타임 인터페이스보다 빌드 타임 선택을 우선합니다.

## 설계 방향

- **DOD 지향**
	- 데이터 배치, 실행 흐름, 비용 모델을 중요하게 봅니다.
	- 객체 모델은 부정하지 않지만, 성능과 책임 경계를 흐리는 추상화는 피합니다.

- **모듈식 엔진**
	- Core, Platform, Engine, Runtime, Editor, Modules 계층을 분리합니다.
	- 각 계층은 자신의 책임만 갖고, 다른 계층의 정책을 대신 결정하지 않습니다.
	- Renderer는 Engine에 고정된 구현이 아니라, Module ABI와 Backend DLL / SO를 통해 연결됩니다.

- **빌드 타임 추상화**
	- 플랫폼처럼 빌드 시점에 고정 가능한 차이는 빌드 시스템이 선택합니다.
	- 같은 계약의 플랫폼별 concrete 구현을 두고, 타겟 빌드가 필요한 구현만 링크합니다.
	- 이 경우 런타임 인터페이스 / vtable / 가상 디스패치를 기본값으로 두지 않습니다.

- **OOP와 DOD의 공존**
	- 인터페이스와 OOP를 전역 금지하지 않습니다.
	- 에디터 런타임 구성, 게임 런타임 구성, 교체 가능한 상위 시스템처럼 런타임에만 결정되는 영역에서는 OOP를 사용할 수 있습니다.
	- 빌드가 이미 아는 것은 빌드로 고정하고, 런타임에만 아는 것은 런타임 구조로 풉니다.

## 참고하는 방향

CyphenEngine은 다음 방향을 참고합니다.

- Unreal Engine
	- 엔진 중심 구조
	- 플랫폼 계층과 Core 계층 분리
	- 파일 / 리소스 / 런타임 책임의 명확한 경계
	- 저수준 API에 대한 명시적 통제

- Data-Oriented Design
	- 불필요한 간접 참조와 런타임 추상화 비용 회피
	- 데이터 흐름과 실행 비용을 우선하는 설계

- 과거 Skull 프로젝트 경험
	- SubSystem류의 OOP + DOD 혼합 구조는 참고합니다.
	- 반대로 과도한 컨테이너화, 스트림화, 추상화 선행 설계는 경계합니다.

## 핵심 원칙

- Core는 OS API를 직접 호출하지 않습니다.
- Platform 계층은 OS 종속 구현을 담당합니다.
- HAL은 Core와 Platform 사이의 내부 계약입니다.
- Runtime과 Editor는 분리합니다. Runtime은 Editor를 알지 못합니다.
- Path는 순수 문자열 유틸리티, File은 파일 내용 I/O helper, FileSystem은 파일 시스템 네임스페이스 관리 API입니다.
- Renderer는 Frame을 RenderCommand IR로 변환합니다.
- Backend는 RenderCommand / ResourceCommand를 실제 그래픽 API 호출로 변환합니다.
- DLL / SO 경계에는 C++ 추상 클래스나 vtable을 노출하지 않습니다. `extern "C"` 진입점과 고정 API 구조체만 넘깁니다.
- ResourceManager는 아직 정식화하지 않습니다.
- RuntimePath 같은 정책 경로 계층은 실제 트리거가 올 때 만듭니다. 테스트 편의를 위해 미확정 계층을 앞당기지 않습니다.

## 렌더러 백엔드 전략

Renderer backend는 플랫폼/드라이버에 따라 교체 가능한 모듈입니다.

- **DX11** — Windows 주력 backend.
- **Vulkan** — 크로스플랫폼 backend. Windows / Linux 양쪽에서 동작하며, Linux의 기본 렌더 경로입니다.
- **OpenGL ES** — 선반행(shelved). 스켈레톤만 유지하며, 웹/Android 바닥 시드로 남깁니다.

## 구조 & 현재 상태 시각화

계층 구조와 현재 검증 상태는 아래 그림으로 요약합니다. 상세(Renderer 실행 흐름, Command IR, Texture2D 업로드 등)는 [Docs/Architecture.md](Docs/Architecture.md)에 정리합니다.

![CyphenEngine 구조 및 현재 상태](Docs/images/cyphenengine-overview.png)

## 현재 상태

2026년 7월 기준, CyphenEngine은 **Windows와 Linux 양쪽에서 Renderer backend module을 로드해 화면 출력까지 검증한 first-light 단계**입니다. 아직 완성된 게임 엔진은 아니며, 엔진 구조가 실제 실행 파일과 backend module 위에서 성립하는지 검증하는 단계입니다.

완료된 주요 기반은 다음과 같습니다.

**Core / 기반 (#1 리팩토링)**
- Build / Core / HAL / Platform / Runtime 계층 재정립
- Time / Path / File / FileSystem / TextCodec Core-Platform 분리
- 플랫폼 정의 3계층(PlatformDefine → framework → define)과 CString / CChar / CTEXT 규약 확정
- Debug 전용 Core I/O 회귀 테스트

**Renderer 모듈화 (#2)**
- LaunchContext / EngineContext 기반 실행 정보 전달
- ModuleDescriptor / ModuleManager / ModuleLoader 기반 동적 모듈 관리
- Renderer Module ABI와 DX11 Renderer Backend DLL 분리 (`extern "C"` + 고정 API 구조체)
- Engine Thread → Render Thread → Backend 실행 흐름, Frame → RenderCommand IR → executeCommandList 경로
- 64-bit word 기반 RenderCommand / ResourceCommand 스트림 (ClearRenderTarget / Present / DrawTexturedQuad)
- Content Codec / Resource / Texture2D 기초 경로, ResourceId 기반 Backend texture table
- Debug fixture에서 Profile.jpg / Profile2.jpg 1초 교체 렌더링 확인

**Linux 전환 · Vulkan first-light (#3)**
- Platform/Linux 구현: `dlopen` ModuleLoader, POSIX PlatformFile, `clock_gettime` PlatformTime, X11 Launch / main
- Windows Vulkan backend DLL 및 Linux Vulkan backend `.so` (`CyphenRendererVulkan`)
- `nativeRenderContextHandle`을 통한 플랫폼 native render context(HINSTANCE / X11 Display) 전달, Xlib `vkCreateXlibSurfaceKHR` surface 생성
- 모듈 export 매크로를 PlatformDefine 기반 공통 헤더(`Modules/Public/ModuleExport.h`)로 일원화
- CMake 빌드 체계화: 공통 `CMake/CyphenTarget.cmake` helper + 루트 CMake + 모듈 CMake로 엔진/모듈이 동일 산출물 규격·build target 공유
- WSL2 Linux GUI에서 `CyphenRendererVulkan.so` 로드, Vulkan surface / swapchain / pipeline 초기화, 리소스 출력(first-light) 확인

자세한 폴더 책임은 `폴더 기능 정리.txt`를 기준으로 관리합니다. 현재 주요 폴더는 다음과 같습니다.

- `CMake` · `Build` · `Core` · `HAL` · `Platform` · `Engine` · `Runtime` · `Editor` · `Modules` · `Test` · `Content` · `Resource` · `Resources` · `DevLog`

## 테스트

Debug 빌드에서 현재 기준선을 검증합니다.

| 항목 | 상태 |
|---|---|
| CoreIoTests (Path / TextCodec / File / FileSystem) | `PASS=69 / FAIL=0` |
| ModuleTests (ModuleCommand / ModuleManager / Renderer 계약) | `PASS=34 / FAIL=0` |
| Windows DX11 backend | 빌드 및 텍스처 표시 확인 |
| Windows Vulkan backend | 빌드 및 텍스처 표시 확인 |
| Linux Vulkan backend | `CyphenRendererVulkan.so` 로드 및 GUI first-light 확인 |

테스트와 진단 출력은 Debug 기준으로 운용합니다. 디버그 출력은 `PRINT_DEBUG_OUTPUT` 경유로 정리했으며, 플랫폼별 실제 출력 경계는 `framework.h`가 소유합니다.

## 빌드

### Windows

Visual Studio `.sln` / `.vcxproj` 기반입니다. 주요 프로젝트: `CyphenEngine`, `CyphenRendererDx11`, `CyphenRendererVulkan`, `CyphenRendererOpenGLES`.

### Linux / WSL2

CMake 기반입니다. 엔진 실행파일과 backend 모듈을 한 configure 안에서 묶어 config / build target 불일치를 방지합니다.

```bash
sudo apt update
sudo apt install cmake ninja-build build-essential libvulkan-dev vulkan-tools mesa-vulkan-drivers glslang-tools libx11-dev libturbojpeg0-dev
```

```bash
cmake -S . -B BuildArtifacts/Intermediate/Linux/x64/Debug/CyphenWorkspace -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCYPHEN_BUILD_TARGET=Editor
cmake --build BuildArtifacts/Intermediate/Linux/x64/Debug/CyphenWorkspace
```

산출물은 `BuildArtifacts/Binaries/<OS>/<Arch>/<Config>/` 아래에 생성됩니다. Linux Debug 대표 산출물:

```text
CyphenEngine
CyphenRendererVulkan.so
TexturedQuad.vert.spv
TexturedQuad.frag.spv
Resources/
```

## 다음 단계 (#4)

#3에서 Linux Vulkan first-light를 확인했으니, #4에서는 그 위의 안정화와 Runtime / Editor 확장을 다룹니다.

- **Linux renderer 안정화**
	- GPU device 선택, validation layer 설정
	- swapchain resize 대응, frame pacing 정리
- **Server / headless 타겟 분리**
	- `Build::IsServerBuild` 기준 X11 include / link 분리
	- Launch 소스 분리(LaunchWindowedX11 / LaunchServer), renderer module 제외 빌드 경로
- **Renderer 구조 확장**
	- FrameQueue 정리, ResourceManager 정식화
	- Mesh / Material 확장, backend별 완성 범위 재정리
	- Dx11 surface seam을 Vulkan과 동일 입력 계약으로 추출
- **Runtime / Editor 경계 확장**
	- Game runtime / Editor runtime 구성 (PIE 형태 최소 실행)
	- UserPreference / ModuleDescriptor resolver 정리
- **플랫폼 확장 검토**
	- Wayland surface 경로, 이벤트 시스템 추출

## 개발 방식

- 작은 단위로 설계하고 검증합니다.
- 구현보다 책임 경계를 먼저 봅니다.
- 트리거가 오기 전까지 계층을 만들지 않습니다.
- 자동화보다 실제 엔진 설계를 우선합니다.
- DevLog는 작업 흐름 단위로 핵심 결정만 압축해 남깁니다.
