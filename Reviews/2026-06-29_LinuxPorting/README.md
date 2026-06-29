# 2026-06-29_LinuxPorting — Linux 포팅 실구현 검토

> 검토의 현재 상태 요약(가변). 범위·상태·현재 결론을 여기서 갱신한다.
> 상세 판단은 `Claud/REVIEW.md` · `Codex/REVIEW.md`, 최종은 `DECISION.md`.

- 주제: #3_2 Linux 포팅 실구현 — Platform/Linux 본체와 raw File 계약 동기화.
- 기준 커밋(baseline): `commit=d2eedf9` (`Source=93`, 2026-06-29 20:46 sync)
- 범위: `Platform/Linux`, `PlatformFile`, `PlatformPath`, `WindowsPath` / `LinuxPath`, `FileHandle` / `FileStream`, Linux CMake 소스 등록, JPEG Linux leaf.
- 제외: Vulkan first-light, Linux windowing, 원본 repo 직접 수정.
- 상태: Evidence-checked

## 현재 결론 (요약)

2026-06-29 기준 Linux 포팅은 25일 LinuxBringup 폐기 초안이 아니라, 28일 이후 개선된 단일 `REVIEW.md` 모델을 따르는 새 검토로 분리한다.

구현 결론:

- `PlatformPath`는 `ToPlatformPath` 단방향 계약만 둔다. `ToEnginePath`는 `Path::Normalize`와 중복되는 죽은 대칭이라 제거한다.
- `WindowsPath` / `LinuxPath`는 플랫폼 native path facade다. `PlatformFile`은 이 facade만 보고 `PlatformPath` / `WindowsString` / `LinuxString` 조합을 직접 알지 않는다.
- Linux `PlatformFile.cpp`는 POSIX fd 기반 raw I/O와 namespace op를 구현한다.
- Linux `PlatformTime.cpp`는 `clock_gettime`, `ModuleLoader.cpp`는 `dlopen` / `dlsym` / `dlclose` 기반이다.
- Linux `Launch.cpp`는 `GEngine`과 `main`을 제공하는 executable link gate다.
- Linux `LinuxString`은 `CString`을 Linux API용 UTF-8 `std::string`으로 전사한다.
- `LinuxJpegCodec.cpp`는 libjpeg-turbo `turbojpeg` 기반 실제 decoder다.
- CMake Linux source list는 `LinuxPath.cpp`와 `LinuxJpegCodec.cpp`를 포함하고, UNIX 링크에서 `Threads`, `dl`, `turbojpeg`를 요구한다.
- renderer module export는 `CYPHEN_RENDERER_MODULE_EXPORT` 토큰만 코드가 소비하고, 실제 플랫폼별 값은 빌드 설정이 주입한다.

검증:

- Windows MSBuild Debug x64 통과.
- Windows CMake configure / build 통과.
- 실제 Linux CMake 빌드는 WSL 배포판 미설치로 미실행.

잔여:

- Linux `Launch.cpp`는 renderer first-light가 아니라 링크 게이트다.
- 실제 Linux 빌드 환경에는 libjpeg-turbo 개발 패키지(`turbojpeg.h`, `libturbojpeg`)가 필요하다.
- Linux renderer module 빌드가 생기면 해당 빌드 설정에서 `CYPHEN_RENDERER_MODULE_EXPORT=__attribute__((visibility("default")))` 같은 값을 주입해야 한다.
- `ModuleLoader`의 `.so` 탐색 경로 정책은 모듈 산출물 레이아웃 확정 시 재검토한다.

## Callback (사용자 개입 · append)

- [2026-06-29] 25일 LinuxBringup은 폐기된 초안이며, 오늘 작업은 28일 개선 프로세스 기준의 29일차 작업으로 수행한다.
- [2026-06-29] 스코프를 나눠 미루지 말고 Handle / Stream / PlatformFile raw 계약과 Linux 실구현을 함께 정리한다.
- [2026-06-29] 동기화 프로세스는 최신 baseline sync(`Source=93`) 기준이다. 낡은 `edit/Codex Source=84` 판단은 폐기한다.
