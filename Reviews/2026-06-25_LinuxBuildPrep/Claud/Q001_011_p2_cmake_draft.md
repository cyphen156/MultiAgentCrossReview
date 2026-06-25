Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: Decision(P2) + 사용자 "실행파일까지 포함" + CyphenEngine.vcxproj 구성
Supersedes: none
Status: Implementation-Draft
Baseline: 2026-06-25 sync. 워크벤치 읽기 전용 → 드롭인 초안. 원본 적용·빌드는 사용자.

# #2_7 P2 드롭인 — CMake 빌드 시스템 (실행파일 타깃 포함)

목표: 공통 코어 + 실행파일(CyphenEngine) 타깃을 CMake로. Linux에서 cmake 구성 + 컴파일 통과,
Platform/Linux 미구현 심볼은 링크 단계 노출(=#3 입력). MSVC vcxproj 병존.

## vcxproj 기준 사실
- ConfigurationType=Application, Toolset v143, include 루트=`Source/`, `/utf-8`+`/permissive-`,
  SubSystem=Windows(WinMain), CharacterSet=Unicode.
- 정의: 공통 `BUILD_TARGET_EDITOR`; Debug `_DEBUG;_WINDOWS;TARGET_PLATFORM_WINDOWS`,
  Release `NDEBUG;_WINDOWS;TARGET_PLATFORM_WINDOWS`.
- PCH: pch.h(Use) / pch.cpp(Create).
- DX11 백엔드 ProjectReference 없음 → 런타임 모듈 로딩. exe는 백엔드 미링크.
- `..\CyphenBuild.props` import(미러 밖) — LanguageStandard/출력경로/추가정의가 있을 수 있어 **대조 필요**.
- 부모 import 탓에 C++ 표준 미확정 → 초안은 cxx_std_17 가정(실제와 대조).

## Windows-only 격리 대상
- `Source/Platform/Windows/**`(Launch/ModuleLoader/PlatformFile/PlatformTime/WindowsString + .rc)
- `Source/Content/Private/Image/Jpeg/WindowsJpegCodec.cpp`(WIC leaf)

## CMakeLists.txt (프로젝트 루트 `CyphenEngine/CMakeLists.txt`)

```cmake
cmake_minimum_required(VERSION 3.20)

project(CyphenEngine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)          # TODO: CyphenBuild.props의 LanguageStandard와 대조
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ----------------------------------------------------------------------------
# 공통 소스 (플랫폼 독립) — vcxproj ClCompile 중 Windows-leaf 제외
# ----------------------------------------------------------------------------
set(CYPHEN_COMMON_SOURCES
	Source/Content/Private/Codec.cpp
	Source/Content/Private/Image/ImageCodec.cpp
	Source/Content/Private/Image/Jpeg/JpegCodec.cpp
	Source/Core/Private/File.cpp
	Source/Core/Private/FileSystem.cpp
	Source/Core/Private/Path.cpp
	Source/Core/Private/Separator.cpp
	Source/Core/Private/TextCodec.cpp
	Source/Core/Private/Thread.cpp
	Source/Core/Private/Time.cpp
	Source/Modules/Private/ModuleBinder.cpp
	Source/Modules/Private/ModuleManager.cpp
	Source/Engine/Private/CyphenEngine.cpp
	Source/Modules/Renderer/Private/Renderer.cpp
	Source/Resource/Private/Texture.cpp
	Source/Test/CoreIO/CoreIOTests.cpp
	Source/Test/Module/ModuleTest.cpp
)

# ----------------------------------------------------------------------------
# 플랫폼 소스
# ----------------------------------------------------------------------------
set(CYPHEN_WINDOWS_SOURCES
	Source/Content/Private/Image/Jpeg/WindowsJpegCodec.cpp
	Source/Platform/Windows/Private/Launch.cpp
	Source/Platform/Windows/Private/ModuleLoader.cpp
	Source/Platform/Windows/Private/PlatformFile.cpp
	Source/Platform/Windows/Private/PlatformTime.cpp
	Source/Platform/Windows/Private/WindowsString.cpp
)

# Linux: 현재 Launch.cpp(빈 스텁)만 존재.
# #3에서 추가될 HAL 계약 구현(아래)이 들어오기 전까지 ModuleLoader/PlatformFile/
# PlatformTime/main 심볼은 링크 단계에서 미해결로 노출된다(= #2_7→#3 경계).
#   Source/Platform/Linux/Private/ModuleLoader.cpp   (dlopen/dlsym/dlclose)   [#3]
#   Source/Platform/Linux/Private/PlatformFile.cpp   (POSIX fd)               [#3]
#   Source/Platform/Linux/Private/PlatformTime.cpp   (clock_gettime)          [#3]
#   Source/Platform/Linux/Private/Launch.cpp         (main 진입점)            [#3 본문]
# 주의: vcxproj의 Platform/Linux/{File,Path,Time}.cpp는 HAL 계약명과 불일치 +
#       Path는 공통 Core라 중복 심볼 위험 → 채택하지 않음(#3에서 정리).
set(CYPHEN_LINUX_SOURCES
	Source/Platform/Linux/Private/Launch.cpp
)

if(WIN32)
	enable_language(RC)
	add_executable(CyphenEngine WIN32
		${CYPHEN_COMMON_SOURCES}
		${CYPHEN_WINDOWS_SOURCES}
		Source/pch.cpp
		Source/Platform/Windows/Resource/CyphenEngine.rc
	)
elseif(UNIX)
	add_executable(CyphenEngine
		${CYPHEN_COMMON_SOURCES}
		${CYPHEN_LINUX_SOURCES}
	)
else()
	message(FATAL_ERROR "Unsupported platform for CyphenEngine.")
endif()

# ----------------------------------------------------------------------------
# include 루트
# ----------------------------------------------------------------------------
target_include_directories(CyphenEngine PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/Source
)

# ----------------------------------------------------------------------------
# 정의 (구성별 _DEBUG/NDEBUG는 전 플랫폼 공통 — P1 매크로 게이트 전제)
# ----------------------------------------------------------------------------
target_compile_definitions(CyphenEngine PRIVATE
	BUILD_TARGET_EDITOR                      # vcxproj 현행(에디터 빌드) 미러
	$<$<CONFIG:Debug>:_DEBUG>
	$<$<CONFIG:Release>:NDEBUG>
)

if(WIN32)
	target_compile_definitions(CyphenEngine PRIVATE
		_WINDOWS
		TARGET_PLATFORM_WINDOWS
		UNICODE
		_UNICODE
	)
elseif(UNIX)
	target_compile_definitions(CyphenEngine PRIVATE
		TARGET_PLATFORM_LINUX
	)
endif()

# ----------------------------------------------------------------------------
# 컴파일 옵션 / PCH
# ----------------------------------------------------------------------------
if(MSVC)
	target_compile_options(CyphenEngine PRIVATE /utf-8 /permissive- /W3)
	# MSVC PCH(선택). 미사용해도 각 TU의 #include "pch.h"로 정상 동작.
	target_precompile_headers(CyphenEngine PRIVATE Source/pch.h)
else()
	target_compile_options(CyphenEngine PRIVATE -Wall -Wextra)
	# Linux PCH는 #define new(_DEBUG)와의 상호작용 회피를 위해 미사용.
	# 각 .cpp 첫 줄 #include "pch.h" 가 include 루트(Source)로 해석됨.
endif()

# ----------------------------------------------------------------------------
# 링크 (Linux: 공통 Thread.cpp=std::thread → pthread, 모듈 로딩 → dl)
# ----------------------------------------------------------------------------
if(UNIX)
	find_package(Threads REQUIRED)
	target_link_libraries(CyphenEngine PRIVATE Threads::Threads ${CMAKE_DL_LIBS})
endif()
# Windows: 기본 시스템 라이브러리(user32 등) MSVC 자동 링크. 백엔드(DX11)는 런타임 로딩.

# ----------------------------------------------------------------------------
# CoreIo 테스트 리소스 복사 (vcxproj CopyCoreIoTestResources Debug 패리티)
# ----------------------------------------------------------------------------
add_custom_command(TARGET CyphenEngine POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy_directory
		${CMAKE_CURRENT_SOURCE_DIR}/Resources/Test/CoreIo
		$<TARGET_FILE_DIR:CyphenEngine>/Resources/Test/CoreIo
)
```

## 합격 기준 (P2)
- **Windows**: `cmake -B build` + 빌드가 기존 vcxproj와 동등 산출(회귀 없음). exe 실행/표시 동일.
- **Linux**: `cmake -B build` 구성 성공 + 공통 코어/exe **컴파일 통과**. 링크에서
  ModuleLoader/PlatformFile/PlatformTime/main 미해결 노출 = #3 시작점.

## 미해결 / #3 이월
- Platform/Linux HAL 구현 4종(위 주석) + Windows-leaf의 Linux 대체(EGL 백엔드/Linux JPEG).
- `CyphenBuild.props` 대조: C++ 표준, 출력 경로, 추가 정의/옵션을 CMake에 반영.
- 창 생성/엔진 진입(WinMain↔main) 경계 = #3.
- (선택) MSVC/CMake 출력 디렉터리 정합, 멀티 config(Debug/Release) generator expression 점검.

## 비고
- 소스는 glob 아닌 명시 리스트(vcxproj 충실 반영 + 신규 파일 시 명시 추가). Linux 스테일 엔트리
  (File/Path/Time)는 의도적으로 제외.
- pch.cpp는 Windows만 포함(MSVC PCH Create 대응). Linux는 불요.
