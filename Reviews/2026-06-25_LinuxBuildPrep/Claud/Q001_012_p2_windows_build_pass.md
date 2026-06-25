Date: 2026-06-25
Question-ID: Q001
Author: Claude
Responds-To: 사용자 CMake 빌드 실행 결과(Windows)
Supersedes: none
Status: Evidence-Check
Baseline: 2026-06-25. 사용자 환경 빌드 증거.

# P2 Windows 빌드 PASS

사용자가 적용한 루트 `CMakeLists.txt`(Q001_011 산출물)로 Windows 빌드 검증.

## 실행
```
cmake -S . -B build-cmake -G "Visual Studio 17 2022" -A x64   # configure OK (3.1s)
cmake --build build-cmake --config Debug                       # build OK
```
환경: MSVC 19.44(VS2022 17.14), Windows SDK 10.0.26100.

## 결과: 성공
- 전 공통 소스 + Windows-leaf(WindowsJpegCodec, Platform/Windows/*) + pch.cpp 컴파일.
- 링크 성공 → `build-cmake/Debug/CyphenEngine.exe` 산출.
- post-build CoreIo 리소스 복사 custom command 실행.
- 에러/경고 없음.

## 증명
- **P1 무회귀**: framework.h crtdbg/PRINT_DEBUG_OUTPUT 재구성이 Windows 빌드에 영향 없음.
- **P2 건전성·패리티**: CMakeLists가 vcxproj와 동등하게 exe 빌드. C++17 OK(표준 불일치 없음 →
  CyphenBuild.props 17 호환 확인됨), RC 컴파일 OK.

## 미검증 (환경 제약)
- **Linux cmake 구성/컴파일** — Linux 툴체인 부재로 미실행. CMakeLists의 Linux 분기
  (TARGET_PLATFORM_LINUX / Threads+dl / framework.h fputs 경계)는 작성됐으나 실측 안 됨.
- Decision의 P2 합격 기준은 "Linux cmake 구성 성공 + 공통 코어 컴파일 통과"를 포함 →
  엄밀 종결에는 Linux 실측 1회 필요(WSL/Docker). 또는 경계를 조정해 Linux-compile을 #3 첫 단계로.

## 판정
P2 Windows 측 = PASS. #2_7의 CMake 빌드 시스템·Windows 패리티·P1 무회귀 확정.
Linux 실측은 별도 결정(아래 README 진행상태 참조).
