Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: Q001_003(Vulkan 산출물) + 사용자 "드래프트 원본 적용 이번 한정 허용"
Supersedes: none
Status: Evidence-Check (Vulkan scaffold BUILD PASS)
Baseline: 2026-06-25 sync (8ed15ad). 원본 레포 C:\Project\CyphenEngine에 직접 적용(사용자 1회 허용).

# Q001_004 — CyphenRendererVulkan 스캐폴드 빌드 통과

## 적용 (사용자 1회 허용, read-only 정책 예외)
artifacts → 원본 레포 적용(CRLF + 탭, working-tree 규약 일치):
- `CyphenRendererVulkan.vcxproj` (Application→DynamicLibrary / Win32 제거 / CyphenBuild.props / Source include / TARGET_PLATFORM_WINDOWS / /utf-8)
- `Source/Private/VulkanRendererModule.cpp` (`GetRendererModuleApi`, `rendererType=Vulkan`)
- `Source/Private/VulkanRenderer.h` / `.cpp` (스텁, 전부 false)
- `CyphenRendererVulkan.vcxproj.user` 교체: 옛 vcxproj 전체를 복사한 **134줄 중복 파일** → Dx11과 동일한 최소본(`ShowAllFiles`, 5줄)로 교정. (이 .user가 MSBuild auto-import되어 소스 이중 컴파일 유발: MSB4011/MSB8027/LNK4042)

## 빌드 증거 (MSBuild, VS2022 v143, Debug|x64)
- 1차 빌드: EXITCODE=0, DLL 생성. 단 .user 중복으로 경고(MSB8027 "VulkanRenderer.cpp 두 번"/LNK4042).
- .user 교정 후 **Rebuild: EXITCODE=0, 경고 0**, 각 .cpp 1회 컴파일.
- 산출물: `BuildArtifacts\Binaries\Windows\x64\Debug\CyphenRendererVulkan.dll` (CyphenBuild.props 출력 규격대로 떨어짐).
- export 확인(dumpbin /exports): `GetRendererModuleApi` 노출 → ModuleLoader 해석 가능, RendererType::Vulkan 인식.

## 판정
**#3_1 Vulkan 스캐폴드 = BUILD PASS.** "모듈 빌드·로드 OK, createRenderer는 Initialize=false로 의도적 실패(백엔드 미구현)" — 경계 정확히 충족.

## 잔여/추적
- `.vcxproj.user`는 본래 per-machine. .gitignore 등재 여부 별도 검토(현재는 정상화만).
- 엔진 RendererType::Vulkan → DLL 이름 매핑 배선 = #3_2.
- vulkan-1.lib / VulkanSDK include + 실제 first-light = #3_2(Windows 먼저).

## 비고
원본 적용은 이번 1회 한정 허용. 표준 정책(미러 read-only, 사용자 적용)은 유지.
