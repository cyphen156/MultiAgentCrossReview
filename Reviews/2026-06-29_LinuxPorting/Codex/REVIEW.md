---
Review-ID: 2026-06-29_LinuxPorting
Author: Codex
Baseline: commit=d2eedf9 Source=93
Session-Id:
Status: Evidence-checked
---

# Codex REVIEW — Linux 포팅 실구현

## 1. 독립 초기판단

Position: REVISE

이 검토는 25일 LinuxBringup 폐기 초안이 아니라 2026-06-29 재동기화 baseline(`Source=93`) 기준으로 수행한다.
이전 `edit/Codex Source=84` 기준 판단은 폐기한다.

기술 판단:

- `PlatformFile`은 raw 파일 open / close / read / write / seek / tell HAL이다.
- `FileHandle`은 native `HANDLE` / fd를 숨기는 raw opaque 슬롯이며 RAII가 아니다.
- `FileStream`은 `FileHandle`을 소유하는 RAII 계층이다.
- `File`의 `ReadAllBytes` / `WriteAllBytes` / `AppendAllBytes`는 raw 계약 위에서 조합한다.
- `WindowsPath` / `LinuxPath`는 플랫폼 native path facade이며, `PlatformFile`은 이 facade만 호출한다.
- `PlatformPath`는 `ToPlatformPath` 단방향 계약만 가진다. `ToEnginePath`는 `Path::Normalize`와 중복되므로 제거된 상태가 맞다.

## 2. 교차검증 — Claude REVIEW 대상

Verdict: AGREE-WITH-CURRENT-SYNC

Claude handoff의 최신 요지는 코드와 맞다.
`ToEnginePath` 소비처는 없고, 역방향 separator 정규화는 `Path::Normalize`가 맡는다.
`WindowsPath` / `LinuxPath` facade는 존재하며, `PlatformFile`이 `PlatformPath` / 문자열 전사 계층을 직접 알지 않도록 하는 현재 구조와 정합한다.

단, 최신 baseline을 `edit/Codex`에 반영하기 전에는 `edit/Codex`가 `Source=84`로 낡아 있었다.
따라서 본 검토는 `Source=93` 동기화 후 파일을 기준으로 한다.

## 3. 수정 결론

Position: REVISE

적용 / 확인 결론:

- `Source/HAL/Private/PlatformPath.h`는 `ToPlatformPath`만 제공한다.
- `Source/Platform/Windows/Private/WindowsPath.cpp`는 `PlatformPath::ToPlatformPath`와 `WindowsString::ToWideString`을 묶는다.
- `Source/Platform/Linux/Private/LinuxPath.cpp`는 `PlatformPath::ToPlatformPath`와 `LinuxString::ToUtf8String`을 묶는다.
- Linux `PlatformFile.cpp`는 POSIX fd 기반 raw 계약과 namespace op를 구현한다.
- Linux `PlatformTime.cpp`는 `clock_gettime` 기반이다.
- Linux `ModuleLoader.cpp`는 `dlopen` / `dlsym` / `dlclose` 기반이다.
- Linux `Launch.cpp`는 `GEngine`과 `main`을 제공해 executable 링크 게이트를 연다.
- Linux `LinuxJpegCodec.cpp`는 libjpeg-turbo `turbojpeg` 기반 실제 decoder다.
- `CMakeLists.txt`는 Windows `WindowsPath.cpp`, Linux `LinuxPath.cpp`, Linux `LinuxJpegCodec.cpp`를 포함한다.
- UNIX CMake 링크는 `Threads`, `${CMAKE_DL_LIBS}`, `turbojpeg`를 요구한다.

금지 / 주의:

- `ToEnginePath` 재도입 금지. 역방향 separator 정규화는 `Path::Normalize`가 맡는다.
- `ToLinuxApiPath` 같은 중복 path+encoding wrapper 금지.
- renderer module export는 코드가 플랫폼 분기하지 않고, 빌드 설정이 `CYPHEN_RENDERER_MODULE_EXPORT` 값을 주입한다.

## 4. 증거 재확인

Evidence-Status: CONFIRMED

확인한 코드 상태:

- `ToEnginePath` 검색 결과: 코드 잔존 없음.
- `PlatformFile.cpp`는 Windows에서 `WindowsPath`, Linux에서 `LinuxPath`를 호출한다.
- `LinuxPath.cpp` / `LinuxPath.h` 존재.
- `LinuxString.cpp`는 UTF-8 CChar 복사와 TextCodec 기반 UTF-8 전사를 제공한다.
- `LinuxJpegCodec.cpp`는 `turbojpeg.h`를 포함하고 실제 decode 경로를 제공한다.
- `Linux Launch.cpp`는 `GEngine`과 `main`을 정의한다.
- `CMakeLists.txt`는 `WindowsPath.cpp`, `LinuxPath.cpp`, `LinuxJpegCodec.cpp`를 포함한다.
- `CyphenEngine.vcxproj`는 Linux leaf source들을 excluded item으로 최신화한다.

검증 결과:

- MSBuild Debug x64: PASS.
- Windows CMake configure: PASS.
- Windows CMake build: PASS.
- Linux CMake: WSL 배포판 미설치로 미실행.

잔여 위험:

- 실제 Linux 빌드 환경에는 libjpeg-turbo 개발 패키지가 필요하다.
- Linux `Launch.cpp`는 renderer first-light가 아니라 링크 게이트다.
- Linux renderer module 빌드 설정은 아직 없으므로 `.so` 빌드가 생길 때 export 토큰 값을 빌드 시스템에서 주입해야 한다.
- `ModuleLoader`는 현재 `moduleName + ".so"`만 구성하므로 모듈 탐색 경로 정책은 산출물 레이아웃과 함께 확정해야 한다.
