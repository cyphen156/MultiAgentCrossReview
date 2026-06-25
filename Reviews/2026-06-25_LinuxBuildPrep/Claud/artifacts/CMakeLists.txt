# ============================================================================
# CyphenEngine — CMake 빌드 (실행파일 타깃)
# ----------------------------------------------------------------------------
# #2_7 P2: 공통 코어 + 실행파일을 CMake로 빌드. MSVC vcxproj와 병존.
# 프로젝트 루트(CyphenEngine.sln / CyphenEngine.vcxproj 옆)에 둔다.
#
# 적용 전 대조 필요:
#   - ../CyphenBuild.props 의 LanguageStandard / 출력 경로 / 추가 정의·옵션
#   - C++ 표준(아래 17 가정)
#
# Linux: 공통 코어 + exe 컴파일 통과까지가 #2_7. ModuleLoader / PlatformFile /
#        PlatformTime / main 진입점은 미구현 → 링크 단계 미해결 노출(= #3 입력).
# ============================================================================

cmake_minimum_required(VERSION 3.20)

project(CyphenEngine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)          # TODO: CyphenBuild.props 와 대조
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
	Source/Content/Private/Image/Jpeg/WindowsJpegCodec.cpp   # WIC leaf
	Source/Platform/Windows/Private/Launch.cpp
	Source/Platform/Windows/Private/ModuleLoader.cpp
	Source/Platform/Windows/Private/PlatformFile.cpp
	Source/Platform/Windows/Private/PlatformTime.cpp
	Source/Platform/Windows/Private/WindowsString.cpp
	Source/pch.cpp                                           # PCH 미사용 시 일반 TU(무해)
)

# Linux: 현재 Launch.cpp(빈 스텁)만 존재.
# #3에서 추가될 HAL 계약 구현이 들어오기 전까지 아래 심볼은 링크 미해결로 노출된다.
#   Source/Platform/Linux/Private/ModuleLoader.cpp   (dlopen/dlsym/dlclose)   [#3]
#   Source/Platform/Linux/Private/PlatformFile.cpp   (POSIX fd)               [#3]
#   Source/Platform/Linux/Private/PlatformTime.cpp   (clock_gettime)          [#3]
#   Source/Platform/Linux/Private/Launch.cpp         (main 진입점 본문)       [#3]
# 주의: vcxproj 의 Platform/Linux/{File,Path,Time}.cpp 는 HAL 계약명 불일치 +
#       Path 는 공통 Core 라 중복 심볼 위험 → 채택하지 않음(#3에서 정리).
set(CYPHEN_LINUX_SOURCES
	Source/Platform/Linux/Private/Launch.cpp
)

# ----------------------------------------------------------------------------
# 타깃
# ----------------------------------------------------------------------------
if(WIN32)
	enable_language(RC)
	add_executable(CyphenEngine WIN32
		${CYPHEN_COMMON_SOURCES}
		${CYPHEN_WINDOWS_SOURCES}
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
# 빌드 산출물 경로 규격화 (CyphenBuild.props 와 동일 골격)
#   <repo>/BuildArtifacts/Binaries/<OS>/<Config>/   (repo 루트 = CMakeLists 상위 ..)
#   역할 분리: Windows 프로덕션 = MSVC/.sln (props 가 Binaries/Windows/<arch>/<Config> 소유).
#   CMake = Linux 전용 → Linux 만 BuildArtifacts/Binaries/Linux 로 규격화.
#   CMake-Windows(프록시 검증용)는 MSVC 소유 영역을 건드리지 않도록 build-cmake/ 기본 위치 유지.
#   per-config 속성 → multi-config · single-config 동일 레이아웃.
# ----------------------------------------------------------------------------
if(UNIX)
	set(CYPHEN_ARTIFACTS_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../BuildArtifacts/Binaries/Linux)
	foreach(cfg IN ITEMS Debug Release)
		string(TOUPPER ${cfg} CYPHEN_CFG_UPPER)
		set_target_properties(CyphenEngine PROPERTIES
			RUNTIME_OUTPUT_DIRECTORY_${CYPHEN_CFG_UPPER} ${CYPHEN_ARTIFACTS_ROOT}/${cfg}
		)
	endforeach()
endif()

# ----------------------------------------------------------------------------
# include 루트 (vcxproj: $(ProjectDir)Source)
# ----------------------------------------------------------------------------
target_include_directories(CyphenEngine PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/Source
)

# ----------------------------------------------------------------------------
# 정의
#   - _DEBUG / NDEBUG 는 전 플랫폼 공통(P1 PRINT_DEBUG_OUTPUT 매크로 게이트 전제).
#     GCC/Clang 은 _DEBUG 를 자동 정의하지 않으므로 여기서 명시.
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
# 컴파일 옵션
#   PCH 는 의도적으로 CMake target_precompile_headers 를 쓰지 않는다.
#   (MSVC /Yc·/Yu 와 pch.cpp 의 충돌, Linux 의 #define new(_DEBUG) 상호작용 회피)
#   각 .cpp 첫 줄 #include "pch.h" 가 include 루트(Source)로 정상 해석된다.
# ----------------------------------------------------------------------------
if(MSVC)
	target_compile_options(CyphenEngine PRIVATE /utf-8 /permissive- /W3)
else()
	target_compile_options(CyphenEngine PRIVATE -Wall -Wextra)
endif()

# ----------------------------------------------------------------------------
# 링크
#   Linux: 공통 Thread.cpp(std::thread) → pthread, 모듈 로딩(#3) → dl.
#   Windows: 기본 시스템 라이브러리(user32 등) MSVC 자동 링크. DX11 백엔드는 런타임 로딩.
# ----------------------------------------------------------------------------
if(UNIX)
	find_package(Threads REQUIRED)
	target_link_libraries(CyphenEngine PRIVATE Threads::Threads ${CMAKE_DL_LIBS})
endif()

# ----------------------------------------------------------------------------
# CoreIo 테스트 리소스 복사 (vcxproj CopyCoreIoTestResources Debug 패리티)
# ----------------------------------------------------------------------------
add_custom_command(TARGET CyphenEngine POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy_directory
		${CMAKE_CURRENT_SOURCE_DIR}/Resources/Test/CoreIo
		$<TARGET_FILE_DIR:CyphenEngine>/Resources/Test/CoreIo
)
