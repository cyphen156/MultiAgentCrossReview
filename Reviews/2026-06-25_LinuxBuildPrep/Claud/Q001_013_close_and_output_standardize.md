Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 결정(#2_7 Linux→#3 이월 + 빌드 산출물 경로 규격화)
Supersedes: none (Q001_011/artifacts CMakeLists 산출물 갱신)
Status: Decision-Followup / Implementation-Draft
Baseline: 2026-06-25. P2 Windows PASS 이후.

# #2_7 마감 결정 + 빌드 산출물 경로 규격화

## 사용자 결정
1. **Linux 실측은 #3 첫 체크포인트로 이월.** Windows-green(P1+P2 빌드 PASS)을 #2_7 "확인"으로 인정, #2_7/#2 마감.
   - 근거: #3는 어차피 Linux 툴체인 + Platform/Linux 구현이 들어오는 단계 → Linux 실제 컴파일은 거기서 Platform 구현과 함께 첫 체크.
   - Decision P2 합격기준의 "Linux cmake 구성/컴파일"은 #3 진입 즉시 수행으로 재배치(경계는 그대로: "컴파일된다"가 #2↔#3 선).
2. **빌드 산출물 경로 규격화**: `<repo>/BuildArtifacts/<Platform>/<Config>/`
   - repo 루트 = `C:/Project/CyphenEngine`(CMakeLists 상위 `..`).
   - Linux → `BuildArtifacts/Linux/<Config>/`, Windows → `BuildArtifacts/Windows/<Config>/`.
   - 기존 vcxproj(Windows) 산출 경로도 `BuildArtifacts/Windows/`로 정렬.

## CMake 반영 (artifacts/CMakeLists.txt 갱신)
```cmake
if(WIN32)
	set(CYPHEN_PLATFORM_DIR Windows)
elseif(UNIX)
	set(CYPHEN_PLATFORM_DIR Linux)
endif()
set(CYPHEN_ARTIFACTS_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../BuildArtifacts/${CYPHEN_PLATFORM_DIR})
foreach(cfg IN ITEMS Debug Release)
	string(TOUPPER ${cfg} CYPHEN_CFG_UPPER)
	set_target_properties(CyphenEngine PROPERTIES
		RUNTIME_OUTPUT_DIRECTORY_${CYPHEN_CFG_UPPER} ${CYPHEN_ARTIFACTS_ROOT}/${cfg})
endforeach()
```
- per-config 속성 → multi-config(VS) · single-config(Ninja/Make) 동일 레이아웃.
- post-build CoreIo 복사는 `$<TARGET_FILE_DIR:CyphenEngine>` 기반 → 자동 동행.
- 결과: `BuildArtifacts/Windows/Debug/CyphenEngine.exe`.

## vcxproj 측 정렬 (대기 — CyphenBuild.props 필요)
- 기존 Windows 산출(BuildArtifacts 직하)을 `BuildArtifacts/Windows/<Config>/`로 옮기려면
  `..\CyphenBuild.props`의 OutDir/IntDir를 수정해야 함. props는 미러 밖 → 내용 확인 후 정확한 diff 제공 예정.
- 목표 형태(예): `<OutDir>...\BuildArtifacts\Windows\$(Configuration)\</OutDir>` +
  IntDir도 Windows 하위. (SolutionDir 기준 경로는 props 실내용에 맞춰 확정.)

## 남은 것
- vcxproj OutDir/IntDir 정렬(props 수신 후).
- #2_7 마감 DevLog 초안(P1+P2, #2 클로즈, #3 입력 명시).
- #3 첫 체크포인트: Linux cmake 컴파일 + Platform/Linux 구현.
