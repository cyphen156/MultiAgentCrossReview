Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 CyphenBuild.props 공유
Supersedes: Q001_013 의 산출물 경로 형태(BuildArtifacts/<Platform>/<Config>) → 본 기록의 Binaries/<OS>/ 구조로 대체
Status: Implementation-Draft
Baseline: 2026-06-25.

# 빌드 산출물 경로 — props 구조에 맞춰 정렬

## 기존 props 구조 (수신본)
- props 위치 = `C:\Project\CyphenEngine\`(MSBuildThisFileDirectory) → CyphenRepoRoot.
- `OutDir = BuildArtifacts\Binaries\$(Platform)\$(Configuration)\` (e.g. Binaries\x64\Debug)
- `IntDir = BuildArtifacts\Intermediate\$(Platform)\$(Configuration)\$(MSBuildProjectName)\`
- PDB/lib = OutDir, LocalDebuggerWorkingDirectory = OutDir.
- 키가 **$(Platform)=x64(arch)** 였고, Binaries/Intermediate 분리 구조 보유.

## 규격화 결정: Binaries/Intermediate 아래 OS 키 한 겹 추가
```
BuildArtifacts/
├── Binaries/
│   ├── Windows/x64/<Config>/         ← MSVC .sln (props)
│   └── Linux/<Config>/               ← CMake
└── Intermediate/
    └── Windows/x64/<Config>/<Proj>/  ← MSVC
```

### props 변경 (artifacts/CyphenBuild.props) — `Windows\` 삽입 2줄
```xml
<OutDir>$(CyphenBuildArtifactsRoot)Binaries\Windows\$(Platform)\$(Configuration)\</OutDir>
<IntDir>$(CyphenBuildArtifactsRoot)Intermediate\Windows\$(Platform)\$(Configuration)\$(MSBuildProjectName)\</IntDir>
```
나머지(TargetName/PDB/lib/디버거 CWD)는 OutDir 파생 → 자동 추종. arch 레벨($(Platform)=x64) 보존.

### CMake 변경 (artifacts/CMakeLists.txt)
- **Linux 만** `BuildArtifacts/Binaries/Linux/<Config>/`로 규격화(RUNTIME_OUTPUT_DIRECTORY_<CONFIG>).
- **CMake-Windows(프록시 검증용)는 redirect 제거** → build-cmake/ 기본 위치 유지. MSVC가 소유한
  BuildArtifacts/Binaries/Windows 와 충돌 방지.

## 비고
- Linux 경로엔 arch 레벨을 넣지 않음(현 x64 단일). 필요 시 #3에서 `Linux/<arch>/` 추가.
- 역할 분리(Q001_014)와 정합: Windows 출력 소유=props, Linux 출력 소유=CMake.
