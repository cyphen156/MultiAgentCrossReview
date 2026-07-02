# 2026-07-02_VulkanLinuxRenderer — #3_4 Linux Vulkan 렌더러 연결 검토

> 검토의 현재 상태 요약(가변). 범위·상태·현재 결론을 여기서 갱신한다.
> 상세 판단은 `Claud/REVIEW.md` · `Codex/REVIEW.md`, 최종은 `DECISION.md`.

- 주제: #3_4 Linux Vulkan renderer — CyphenRendererVulkan.so 빌드, 산출물 배치, Linux surface/window 소유 경계 검토.
- 기준 커밋(baseline): `2026-07-02T13:26 sync | commit=unknown Source=93`
- 범위: `CyphenRendererVulkan` Linux 빌드 전환, Vulkan surface 생성 위치, X11/Wayland 의존성 소유 경계, renderer module `.so` 산출물 배치, export visibility 주입, headless/server 실행과 windowed renderer 실행 경계.
- 제외: 원본 repo 직접 수정, ResourceManager / Mesh / Material 확장, Vulkan feature 완성, Windows Dx11 경로 재설계.
- 상태: Open

## 현재 결론 (요약)

2026-07-02 기준 새 검토를 연다.

현재 baseline의 DevLog는 #3_3에서 Windows Vulkan first-light를 확인했고, 다음 작업으로 Linux #3_4에서 `CyphenRendererVulkan.so` 빌드와 산출물 배치를 연결하며 Linux Vulkan surface 생성 위치와 X11 의존성 소유 경계를 다시 검토한다고 기록한다.

이번 검토의 핵심 질문은 다음과 같다.

- Linux renderer module `.so`를 기존 Renderer Module ABI와 산출물 레이아웃에 어떻게 연결할 것인가.
- Linux window / surface 생성 책임을 Launch, Platform/Linux, RendererVulkan module 내부 HAL 중 어디에 둘 것인가.
- X11 / Wayland 의존성을 기본 Linux 실행 경로에 고정하지 않으면서 windowed renderer first-light를 어떻게 검증할 것인가.
- headless/server 실행과 windowed renderer 실행을 빌드 설정과 실행 설정에서 어떻게 분리할 것인가.

## Callback (사용자 개입 · append)

- [2026-07-02] 랩탑 작업 시작. 입력 지연 문제 해결 후 #3_4 Vulkan 렌더러 Linux 작업의 멀티에이전트 프로세스를 가동한다.
- [2026-07-02] 추가 질문: (1) Linux renderer module 빌드 타깃을 CyphenEngine 실행파일과 동일한 CMake 산출물/빌드 규격으로 둘지 결정한다. (2) 어제 마감 직전 고민했던 Linux Launch의 main X server 연결 초기화 책임과 전달 계약을 결정한다.
