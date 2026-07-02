# #2 Renderer 모듈 개발 회고

지난 글에서 리팩토링으로 엔진 바닥을 다 갈아엎었다고 했다.

이번 글은 그 위에 올라간 첫 번째 실체, 렌더러를 엔진에 붙인 이야기다.

#2 브랜치의 이름은 **Renderer 모듈 개발**이었다.

이 브랜치의 목표는 명확했다.

렌더러를 동적 링크 라이브러리로 분리하고, 엔진이 그 모듈을 로드해서 화면에 두 장의 이미지 `Profile.jpg` / `Profile2.jpg`를 1초마다 번갈아 그리게 만드는 것.

겉으로 보면 단순히 이미지 두 장이 번갈아 뜨는 장면이다.

하지만 그 안에는 엔진 초기화, 모듈 로드, 렌더 스레드, 커맨드 스트림, 이미지 코덱, GPU 리소스 업로드, 백엔드 렌더링까지 이어지는 전체 경로가 들어 있다.

## 1. 렌더러를 DLL로 떼어내기

가장 먼저 한 일은 렌더러를 엔진 밖으로 꺼내는 것이었다.

DX11 렌더러를 `CyphenRendererDx11`이라는 독립 DLL 프로젝트로 분리했다.

엔진은 렌더러가 내부에서 어떻게 그리는지 알 필요가 없다. 엔진은 월드 상태를 확정하고, 그것을 Frame이라는 규격으로 만들어 "이걸 그려라"라고 넘기면 된다.

여기서 중요한 것은 DLL 경계의 규약이었다.

C++ 추상 클래스나 vtable을 DLL 밖으로 노출하면 컴파일러, 런타임, 빌드 설정 ABI에 묶이기 쉽다. 그래서 DLL 경계에는 딱 두 가지를 뒀다.

```cpp
extern "C" GetRendererModuleApi(RendererModuleApi* out);
```

```text
RendererModuleApi
	고정된 함수 포인터 구조체
```

DLL은 `GetRendererModuleApi` 심볼 하나만 export한다.

엔진이 이 함수를 호출하면 DLL은 함수 포인터가 담긴 고정 구조체를 채워 준다. 엔진은 이 구조체의 ABI 버전과 `RendererType`을 먼저 검증한 뒤 사용한다.

vtable 대신 **C ABI 진입점 + 고정 함수 포인터 구조체**.

이게 이번 브랜치 내내 지킨 원칙이다.

이렇게 떼어 놓으면 나중에 백엔드를 통째로 갈아끼울 수 있다. 실제로 DX11을 Vulkan으로 교체하는 일은 다음 브랜치에서 증명하게 된다.

## 2. 엔진과 모듈을 잇는 배관

DLL만 만든다고 엔진에 붙는 것은 아니다.

엔진은 어떤 모듈을 켜고, 언제 로드하고, 언제 내릴지 관리해야 한다.

이 책임을 세 조각으로 나눴다.

```text
ModuleDescriptor
	엔진이 사용할 모듈의 이름과 활성 상태

ModuleManager
	활성 모듈 로드, 비활성 모듈 언로드, 수명 관리

ModuleLoader
	플랫폼별 동적 라이브러리 로드 / 심볼 조회 / 언로드
```

경계를 특히 신경 썼다.

`ModuleLoader`는 모듈 종류나 API 버전을 판단하지 않는다. 물리적인 로드, 심볼 조회, 언로드만 한다.

"이게 렌더러 모듈인지", "버전이 맞는지", "이 백엔드를 써도 되는지"를 판단하는 것은 그 위 계층의 몫이다.

이렇게 해야 나중에 Windows의 `LoadLibrary`를 Linux의 `dlopen`으로 바꿀 때 Platform 구현만 갈아 끼울 수 있다. 지난 글에서 정리한 "플랫폼 구현은 Platform 밑으로" 원칙이 여기서 그대로 적용됐다.

엔진 초기화 경계에는 실행 정보를 나르는 그릇도 추가했다.

`LaunchContext`는 플랫폼 Launch가 수집한 주 윈도우 정보와 모듈 목록을 엔진에 전달한다. `EngineContext`는 그중 엔진 실행 중 필요한 상태만 보관한다.

모듈 로드 실패는 엔진 초기화 실패와 분리했다. 렌더러가 없더라도 엔진 자체는 뜰 수 있어야 하기 때문이다.

여기에는 Package / Extension / Plugin에 가까운 관점이 들어 있다. 모듈은 엔진 본체가 아니라, 엔진 실행 환경에 추가로 붙는 부품이다.

## 3. 명령을 데이터로 흘려보내기

엔진이 렌더러 함수를 직접 하나씩 호출하는 구조로 가면, 기능이 늘 때마다 DLL 함수표가 계속 커진다.

그건 피하고 싶었다.

그래서 엔진은 "무엇을 그릴지"를 데이터로 만들고, 모듈이 그 데이터를 해석하는 구조로 갔다.

```text
Engine Thread
	Frame 생산

Render Thread
	Frame -> RenderCommandList 작성

Backend DLL
	RenderCommandList 파싱
	실제 D3D11 API 호출
```

`RenderCommand`는 64비트 word를 이어 붙인 IR, 즉 중간 표현이다.

#2_5에서는 명령을 `ClearRenderTarget`과 `Present` 두 개로만 한정했다. 먼저 "엔진이 만든 명령 스트림이 DLL에서 실제로 실행되어 화면이 갱신되는 경로"부터 뚫는 것이 목표였다.

기능은 함수표를 늘려서 확장하지 않는다.

IR에 새 명령을 추가해서 확장한다.

이게 이번 구조의 핵심이다.

스레드도 갈랐다.

Frame을 만드는 것은 Engine Thread, Frame을 command로 바꾸고 backend를 돌리는 것은 Render Thread다.

그리고 Frame에는 대용량 픽셀 데이터를 싣지 않는다. 뒤에 나올 텍스처도 Frame에는 `ResourceId`만 담는다. `ResourceId`는 GPU에 올라간 리소스를 가리키는 번호다.

이렇게 하면 렌더링 경로가 단순해진다.

엔진은 커맨드 버퍼 포인터를 넘기고, 렌더러는 그 포인터를 기준으로 명령 word를 순차적으로 읽는다. 명령은 64비트 word 단위로 정렬되어 있으므로, backend는 command header를 보고 다음 인자나 다음 명령으로 점프할 수 있다.

이 구조는 지금은 보류되어 있는 Skul 프로젝트에서 얻은 경험의 영향도 있다. 리소스 관리와 렌더 커맨드를 나누다 보니 자연스럽게 비슷한 형태로 흘러갔다.

## 4. 텍스처 두 장 번갈아 그리기

Clear / Present로 화면 갱신을 확인했으니, 이제 진짜 무언가를 그릴 차례였다.

대상은 `Profile.jpg`와 `Profile2.jpg` 두 장으로 정했다.

먼저 이미지를 읽어야 했다.

Unity에서는 내장된 기능을 통해 데이터를 변환하면 그만이었지만, 여기에는 그런 것이 없다. 엔진이 직접 파일을 읽고, 포맷을 해석하고, GPU 리소스로 올려야 한다.

여기서 빠르게 드러난 문제가 있다.

이미지 해석조차 플랫폼이나 외부 라이브러리 경계에 따라 구현이 달라질 수 있다는 점이다.

그래서 코덱 계층을 따로 뒀다.

파일 해석은 `Content/Codec` 책임으로 분리했다. 렌더러는 파일 포맷을 알지 않는다. 렌더러는 이미 해석된 리소스를 GPU에 올리고, 그 리소스를 그릴 뿐이다.

전체 흐름은 이렇게 된다.

```text
File / FileSystem
	파일 바이트 읽기

Content / Codec
	확장자로 포맷 판별
	JpegCodec으로 RGBA8 해석

ResourceCommand
	렌더 루프 진입 전 backend에 업로드 요청

Backend Device
	D3D11 Texture2D + ShaderResourceView 생성
	ResourceId로 내부 테이블에 보관
```

여기서 업로드와 그리기를 확실히 갈랐다.

픽셀을 GPU에 올리는 작업은 렌더 루프에 들어가기 전에 `ResourceCommand`로 한 번만 한다. 매 프레임 도는 `DrawTexturedQuad`는 픽셀을 모른다.

`DrawTexturedQuad`는 `ResourceId` 하나만 참조한다. backend는 자기 내부 텍스처 테이블에서 그 번호에 맞는 리소스를 꺼내 그린다.

프레임이 무거워질 이유가 없다.

두 장의 텍스처를 모두 업로드해 둔 뒤, `Time::ElapsedTime` 기준으로 1초마다 Frame에 넣을 `ResourceId`만 바꿨다.

처음에는 두 장을 같은 프레임에 모두 넣어 봤다. 하지만 fullscreen quad가 두 번 그려지면서 뒤 텍스처가 앞을 덮었다. 그래서 Frame에는 매번 하나의 textured quad만 넣기로 했다.

이게 화면에서 두 장이 1초마다 번갈아 뜨는 이유다.

별것 아닌 장면 같지만, 이 한 컷에 엔진 -> 코덱 -> 리소스 업로드 -> 커맨드 -> 백엔드 -> GPU로 이어지는 경로가 전부 살아 있다.

## 5. 다시 플랫폼 경계로, 그리고 Linux 준비

Windows에서 그리는 이야기는 여기까지다.

#2 브랜치의 마지막 단계인 #2_7에서는 "이 구조가 다른 플랫폼에서 컴파일이라도 되는가"를 확인했다.

실제로 Linux에서 그리는 것은 다음 브랜치의 몫이었다. 이번에는 컴파일 경계까지만 밀어붙였다.

플랫폼별 시스템 헤더, OS 타입, 디버그 힙, 디버그 출력을 `framework.h` 한 곳으로 모았다.

디버그 출력은 `PRINT_DEBUG_OUTPUT` 매크로로 통일했다.

```text
Windows    OutputDebugStringA
Linux      std::fputs(stderr)
```

여기저기 박혀 있던 `OutputDebugStringA` 직접 호출도 이 매크로로 치환했다.

그리고 CMake를 도입했다.

기존 MSVC `.vcxproj` / `.sln`은 Windows 프로덕션 빌드로 그대로 두고, CMake는 Linux 빌드 전용으로 병존시켰다.

공통 소스와 Windows 전용 구현을 분리해서, Linux 타깃에서는 Windows JPEG codec, `Platform/Windows`, Windows resource를 제외한다.

#2와 #3의 경계는 딱 한 문장으로 정했다.

**Linux에서 컴파일된다.**

빠진 플랫폼 구현은 어차피 링크 단계에서 드러난다. 그러니 이 단계에서는 Windows 전용 코드가 공통 경계로 새어 나오지 않도록 빌드 구조를 먼저 정리하는 것이 중요했다.

## 정리하며

이번 브랜치의 결론을 추리면 이렇다.

- 렌더러를 `CyphenRendererDx11` DLL로 떼어냈다.
- DLL 경계는 `extern "C"` 진입점과 고정 API 구조체로 제한했다.
- 모듈은 Package / Extension / Plugin 관점의 추가 부품으로 보고, `ModuleDescriptor` / `ModuleManager` / `ModuleLoader`로 수명을 관리했다.
- 엔진은 Frame을 64비트 `RenderCommand` IR로 바꿔 흘리고, backend가 순차로 읽어 해석한다.
- 기능 확장은 함수표가 아니라 IR 명령 추가로 한다.
- Frame에는 픽셀을 싣지 않는다.
- 이미지는 Codec으로 RGBA8까지 해석하고, GPU 리소스로 미리 올린 뒤 Frame에서는 `ResourceId`만 참조한다.
- 렌더러는 파일 포맷도, WIC도 모른다.
- `Profile.jpg` / `Profile2.jpg`를 1초마다 교체 렌더링해 전체 경로를 확인했다.
- `framework.h`로 플랫폼 컴파일 경계를 통합하고, Linux 빌드용 CMake를 병존 도입했다.

리팩토링(#1)이 "플랫폼을 빌드 시점에 고를 수 있는 바닥"이었다면, 이번(#2)은 그 위에 "백엔드를 통째로 갈아끼울 수 있는 렌더러 모듈"을 올린 셈이다.

화면에 뜬 것은 이미지 두 장뿐이었지만, 그 두 장은 경로 전체가 살아 있다는 증거였다.

다음 글에서는 이 구조를 진짜로 다른 플랫폼에 태운 이야기, #3 브랜치를 정리하려 한다.

같은 CMakeLists로 Linux에서 컴파일하고, 링크 단계에서 드러난 빈 플랫폼 구현을 채우고, 끝내 DX11 대신 Vulkan backend를 끼워 같은 화면을 다시 띄우기까지의 이야기다.
