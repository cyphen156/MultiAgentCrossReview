# #3_4 First Patch Revision — nativeRenderContextHandle 적용안

## 결론

이번 구현은 새 `RendererCreateInfo` 구조체를 만들지 않는다.
`LaunchContext`에 프로세스 대표 render-context anchor 하나를 추가하고, 기존 `NativeWindowInfo`와 함께 Renderer ABI로 직접 전달한다.

```cpp
struct LaunchContext
{
	void* nativeRenderContextHandle = nullptr;
	NativeWindowInfo mainWindowInfo;
	std::vector<ModuleDescriptor> moduleDescriptors;
};
```

역할:

- `nativeRenderContextHandle`: backend가 main window를 native render surface로 해석할 때 필요한 platform 대표 anchor
- `mainWindowInfo`: 프로세스를 대표하는 main window identity와 초기 extent
- `moduleDescriptors`: UserPref/descriptor resolver가 선택한 module 구성

`NativeWindowInfo`에는 connection/display 필드를 추가하지 않는다.

## Platform Mapping

```text
Windows Launch
	nativeRenderContextHandle = HINSTANCE
	mainWindowInfo.nativeWindowHandle = HWND

Linux X11 Launch
	nativeRenderContextHandle = Display*
	mainWindowInfo.nativeWindowHandle = X11 Window을 uintptr_t 경유로 실은 값

macOS 후보
	nativeRenderContextHandle = CAMetalLayer* 또는 NSView*
	mainWindowInfo.nativeWindowHandle = NSWindow* 또는 NSView*
```

X11 `Window`는 포인터가 아니라 정수 handle이므로 `void*`에 싣는 캐스팅이 발생한다.
이 캐스팅은 LaunchContext 생성과 backend surface 생성의 bootstrap 경계에만 둔다.
프레임마다 또는 command마다 반복해서 캐스팅하지 않는다.

## Renderer ABI

`CreateRendererFunction`은 render-context anchor와 window info를 직접 받는다.

```cpp
using CreateRendererFunction =
	RendererModuleResult(*)(
		void* nativeRenderContextHandle,
		const NativeWindowInfo* windowInfo,
		RendererHandle* outRendererHandle);
```

시그니처가 바뀌었으므로 ABI generation은 증가한다.

```cpp
constexpr uint32 RENDERER_MODULE_ABI_GENERATION = 5;
```

## Vulkan Surface HAL

Vulkan surface 생성은 `NativeWindowInfo`만으로는 충분하지 않다.
따라서 `CreateVulkanSurface`도 같은 render-context anchor를 받는다.

```cpp
bool CreateVulkanSurface(
	VkInstance instance,
	void* nativeRenderContextHandle,
	const NativeWindowInfo& windowInfo,
	VkSurfaceKHR* outSurface);
```

Windows Vulkan:

```text
nativeRenderContextHandle -> HINSTANCE
windowInfo.nativeWindowHandle -> HWND
vkCreateWin32SurfaceKHR
```

Linux X11 Vulkan:

```text
nativeRenderContextHandle -> Display*
windowInfo.nativeWindowHandle -> Window
vkCreateXlibSurfaceKHR
```

Dx11/Dx12:

```text
nativeRenderContextHandle 현재 미사용 가능
windowInfo.nativeWindowHandle -> HWND
```

## Remaining Notes

- `NativeWindowInfo`는 장기적으로 window/camera/render-target 체계가 붙으면 더 신중히 재설계해야 한다.
- 지금 패치에서는 native window handle 캐스팅을 bootstrap 경계에 한정한다.
- Server의 X11 include/link/source 분리는 #3_4 범위 밖이다.
- `Display*`라는 Linux 세부 이름을 공통 타입 이름으로 승격하지 않는다.

