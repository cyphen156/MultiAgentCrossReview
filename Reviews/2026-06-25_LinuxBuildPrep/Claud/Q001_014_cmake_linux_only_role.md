Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 결정(Windows는 MSVC/.sln 유지, CMake는 Linux 전용)
Supersedes: Q001_012/Q001_013 중 "CMake Windows 빌드를 vcxproj와 1:1 정렬" 후속작업 (취소)
Status: Decision-Followup
Baseline: 2026-06-25. P2 Windows 빌드 PASS 이후 역할 확정.

# 빌드 시스템 역할 분리: Windows=MSVC, Linux=CMake

## 사용자 결정
- **Windows 프로덕션 빌드 = 손수 vcxproj/.sln (Visual Studio).** IDE·디버깅 편의 우선.
- **CMake = Linux 전용.** Windows를 CMake로 상시 빌드하지 않음.

## 함의
- **취소(불필요해짐)**: CMake Windows 빌드를 vcxproj와 1:1로 맞추는 작업 — `/sdl`, PCH,
  Release LTCG(/GL,/LTCG), `CyphenBuild.props`의 CMake 반영. Windows를 CMake로 안 쓰므로 무의미.
- **유지 권고**: CMakeLists의 `if(WIN32)` 분기는 **남긴다**. 근거:
  - Linux 박스 없이 CMakeLists 변경을 검증하는 유일한 방법 = Windows에서 CMake 프록시 빌드(이번에 실증).
  - `build-cmake/` 별도 폴더 → MSVC/.sln 워크플로와 무간섭. 비용 0.
  - 역할: Windows 분기=프록시 검증용 / Linux 분기=실제 빌드용. Windows 프로덕션=.sln.

## P2 빌드 검증의 의의 (재해석)
- Windows CMake 빌드 PASS는 "Windows를 CMake로 빌드하겠다"가 아니라, **CMakeLists 기술서가
  정확함(소스셋·정의·구조)을 Linux 부재 상태에서 입증**한 것. #3 Linux 컴파일 리스크 사전 제거.

## 남은 작업 (단순화됨)
1. **vcxproj 출력 규격화**: .sln 빌드 산출을 `BuildArtifacts/Windows/<Config>/`로.
   CMake와 무관, `CyphenBuild.props` OutDir/IntDir 수정(파일 수신 후 정확 diff).
2. **#2_7 마감 DevLog 초안** (P1+P2, #2 클로즈, #3 입력=Linux 컴파일+Platform/Linux 구현).
