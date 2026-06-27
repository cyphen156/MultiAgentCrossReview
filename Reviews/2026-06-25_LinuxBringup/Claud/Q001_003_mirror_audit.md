Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 "미러 확인 + Vulkan 세팅 + 누락 점검 + 이상하면 원본레포 확인"
Supersedes: none
Status: Evidence-Check + Implementation-Draft(Vulkan scaffold)
Baseline: 2026-06-25 sync (8ed15ad). 워크벤치 미러 = 원본 레포(C:\Project\CyphenEngine) 파일셋 동일 확인.

# Q001_003 — 미러 감사 (Platform/Linux + CyphenRendererVulkan)

## 점검 방법
워크벤치 미러와 원본 레포(C:\Project\CyphenEngine) 파일 목록 대조 → **동일**(최신 sync). 미러에서 직접 감사. 모든 신규 파일 빈 상태(0~1줄) = 사용자 "파일만 생성" 정상.

## A. Platform/Linux 파일셋 — 누락 없음

| Windows Private | Linux Private | 판정 |
|---|---|---|
| Launch.cpp | Launch.cpp | ✓ |
| ModuleLoader.cpp | ModuleLoader.cpp | ✓ |
| PlatformFile.cpp | PlatformFile.cpp | ✓ |
| PlatformTime.cpp | PlatformTime.cpp | ✓ |
| WindowsString.cpp/.h | LinuxString.cpp/.h | ✓ (Q001_001 §A에서 누락했던 5번째 부품. 사용자가 보완) |
| Public/targetver.h | — | Windows 전용(PCH 타깃 버전), Linux 불요 |
| Resource/*.rc·ico | — | Windows 전용 |

→ 파일 레벨 누락 0.

## B. ★설계 경고 — LinuxString은 wide 미러 금지

- WindowsString 존재 이유 = **Win32가 wchar_t 요구**. `ToWideString(CString→std::wstring)`, 호출처 = Windows `ModuleLoader.cpp:23`, `PlatformFile.cpp:117`.
- `define.h`: CChar 미지정 시 **UTF-8 기본**, 그리고 `CCHAR_IS_WCHAR && !PLATFORM_WINDOWS` = `#error` → **Linux는 UTF-8/UTF-16만, WCHAR 불가**.
- Linux 기본(UTF-8): `CString = std::basic_string<char>`, POSIX(`open`/`dlopen`/…)는 `const char*` → `path.c_str()` 직결, **변환 불필요**.
- **결론: LinuxString에 ToWideString을 미러링하면 틀림.** 선택지:
  1. **(권장) LinuxString 유지 + 역할 교정** = `ToNarrowString(const CString&, std::string&)`. UTF-8 정책=identity 복사, UTF-16 정책=UTF-8 변환. 매크로 `CLINUX_TEXT(str) str`. 플랫폼 String 부품 슬롯 대칭 유지 + UTF-16 분기 대비.
  2. LinuxString 폐기 + Linux ModuleLoader/PlatformFile에서 `.c_str()` 직접 사용(UTF-8 고정 전제).
- **사용자 결정 필요.** 결정 전 LinuxString 내용 미작성 유지(현재 빈 파일 그대로가 안전).

## C. ★Vulkan vcxproj — 모듈 DLL 프로젝트가 아니라 콘솔앱 템플릿

`CyphenRendererVulkan.vcxproj`는 Dx11 모듈을 미러링한 게 아니라 VS 기본 "콘솔 애플리케이션" 템플릿에 파일만 추가한 상태. Dx11(정상 모듈 DLL 프로젝트) 대비 결함:

| 항목 | Dx11(정답) | Vulkan(현재) | 영향 |
|---|---|---|---|
| ConfigurationType | DynamicLibrary | **Application** | DLL 아님 → ModuleLoader 로드 불가 **(치명)** |
| Platforms | x64만 | Win32 + x64 | 엔진 x64 전용(`sizeof(void*)==8` static_assert) → Win32 무의미 |
| CyphenBuild.props import | 있음 | **없음** | 출력 경로/규격 미적용 → DLL이 BuildArtifacts\Binaries로 안 떨어짐 |
| AdditionalIncludeDirectories …\Source | 있음 | **없음** | RendererModule.h 등 계약 헤더 못 찾음 **(치명)** |
| Preprocessor | _WINDOWS;TARGET_PLATFORM_WINDOWS | WIN32;_CONSOLE | TARGET_PLATFORM_* 부재 → PlatformDefine.h `#error` **(치명)** |
| /utf-8 | 있음 | 없음 | 소스 인코딩 |
| Contract ClInclude | NativeWindowInfo/RendererModule/RendererTypes | 없음 | 솔루션 가시성(비치명) |
| ProjectGuid | 고유 | 고유 ✓ | — |
| .filters | Dx11엔 없음 | Vulkan엔 있음(3파일 정상 참조) | 무해 |

## D. 산출물 (copy-ready) — `Claud/artifacts/CyphenRendererVulkan/`

- `CyphenRendererVulkan.vcxproj` — Dx11 미러 교정(x64 단독 / DynamicLibrary / CyphenBuild.props / Source include / TARGET_PLATFORM_WINDOWS / /utf-8). GUID·RootNamespace는 기존 고유값 유지. DX 링크 의존성 없음(vulkan-1.lib는 #3_2).
- `VulkanRenderer.h` / `.cpp` — 스텁. Initialize/Shutdown/ExecuteCommandList/(Debug)ExecuteResourceCommandList 전부 미구현(false).
- `VulkanRendererModule.cpp` — Dx11RendererModule.cpp 미러, `rendererType = RendererType::Vulkan`. `GetRendererModuleApi` 성공 → 모듈 로드 & Vulkan 인식. `createRenderer`는 Initialize=false로 의도적 실패 = **"모듈 로드 OK, 백엔드 미구현"**의 정직한 스캐폴드 상태.
- `.filters`는 현재본 정상(3파일 참조) → 변경 불요.

## E. 추적 항목 (#3_1 → #3_2)

- 모듈 export 매크로화(`__declspec(dllexport)` → Linux visibility-default): ModuleLoader/dlopen 단계와 묶음(Q001_002). 스텁은 Dx11과 동일 raw `__declspec` 유지.
- 엔진 `RendererType::Vulkan` → `"CyphenRendererVulkan"` DLL 이름 매핑 배선 = 실제 Vulkan 선택 시점(#3_2).
- vulkan-1.lib / VulkanSDK include 경로 = #3_2 first-light.

## 비고
미러 적용은 사용자. 본 산출물은 드래프트(read-only 미러 정책). Codex 부재 → Claude 단독 감사.
