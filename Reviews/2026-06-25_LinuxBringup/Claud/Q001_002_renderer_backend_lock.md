Date: 2026-06-25
Question-ID: Q001
Author: Claude(권고) + User 확정
Responds-To: Q001_001 + 사용자 결정(Vulkan 채택/GLES 보류/Metal 포기) + WebGL 질의
Supersedes: none (Q001_001 §1·§4의 렌더러 라인 구체화)
Status: Decision-Followup (렌더러 백엔드 라인 락)
Baseline: 2026-06-25 sync (8ed15ad / #2 마감 직후)

# Q001_002 — 렌더러 백엔드 라인 확정 + #3_1/#3_2 경계

## 확정 (사용자 결정)

1. **크로스플랫폼/Linux 렌더러 백엔드 = Vulkan.** 메인 = Dx11 불변.
2. **GLES = 보류(shelve).** `CyphenRendererOpenGLES` 스켈레톤 유지, **미투자**. 미래 web(WebGL)·Android-floor·fallback의 씨앗.
3. **Metal = 포기.** 애플 영역, 기초 드로우조차 안 함.
4. **포팅 타깃 라인:** Dx11(main) + Vulkan + Dx12 / GLES 보류 / Metal out.

## 근거 요약

- **모듈 경계 대칭:** 백엔드는 `GetRendererModuleApi` 하나 export하는 DLL일 뿐(검증: `Dx11RendererModule.cpp`). 엔진 `Renderer`는 `ModuleLoader`로 어느 DLL이든 동일하게 봄 → 백엔드 선택의 엔진·계약 측 추가비용 0, 복잡도는 DLL 내부에만 격리.
- **백엔드 표면 = 4함수:** `createRenderer / destroyRenderer / executeCommandList / (Debug)executeDebugResourceCommandList`(`RendererModule.h`). 그리기는 전부 `RenderCommandList` IR → `executeCommandList`의 IR 번역 = 예제 다듬기 수준.
- **무게는 `createRenderer`(init)에 집중:** swapchain/render pass/pipeline/descriptor set/sync/memory. 유일하게 "예제 다듬기"보다 무거운 1회성 덩어리 → **Windows-first + validation layer**로 흡수.
- **학습곡선:** Dx11도 AI 작성 + 사용자 검토(로직 흐름·코드 스탠다드·구현 누락)로 진행. Vulkan도 동일 워크플로로 흡수 — "질문하며 학습"이 맞는 형태.
- **설계 선반영:** `RendererType`에 `Vulkan` 이미 존재(`RendererTypes.h:15`).

## #3_1 / #3_2 경계

- **#3_1** = Platform 미러(A: Linux `PlatformTime`/`PlatformFile`/`ModuleLoader`/`Launch` 실구현, Windows 동명 구현이 레퍼런스) + **`CyphenRendererVulkan` 스캐폴드**.
  - 스캐폴드 = `CyphenRendererDx11` 미러링: `GetRendererModuleApi` 스텁(`rendererType = Vulkan`, 함수포인터 stub), vcxproj(→이후 CMake), DLL 산출, 디스크립터 배선. **빌드·로드 OK, 아직 안 그림.**
  - #3_1 본체 = Platform 미러. 렌더러는 스캐폴드까지로 끊어 #3_1을 블로킹하지 않음.
- **#3_2** = Vulkan first-light, **Windows에서 먼저**(validation layer + RenderDoc). 이후 Linux first-light는 "이미 동작하는 백엔드"로 Platform 미러만 증명.
- **원칙: Vulkan과 Linux를 동시에 디버깅하지 않는다.**

## 발견한 이식 항목

- `extern "C" __declspec(dllexport)` (`Dx11RendererModule.cpp:93`, 유일 export 지점)은 **Windows 전용**. Linux .so는 visibility-default(`__attribute__((visibility("default")))`) 매크로 필요. **모든 모듈 DLL 공통 이식 항목** → ModuleLoader(dlopen) 작업과 한 묶음, Vulkan 모듈도 동일 적용.

## 파킹 (오늘 결정과 무관, 미래)

- **WebGL/웹:** Vulkan은 브라우저 미지원(브라우저 = WebGL/WebGPU). 웹 타깃 시 백엔드 = **GLES→WebGL(Emscripten)** 또는 **WebGPU 신규 백엔드**(explicit-API 모델 = Vulkan과 동일, 경험 전이됨). 단 웹은 렌더러가 아니라 **Platform 전면 재포트**(wasm: dlopen 불가/가상 FS/`requestAnimationFrame` 루프/스레드 제약) = 별도 플랫폼 포트. → 보류된 GLES가 그 씨앗.
- **Android-floor:** Vulkan은 저가·구형 Android 드라이버 단편화 → 최저 공통 호환은 여전히 GLES. 보류된 GLES가 그 역할.

## 비고

- Codex 부재 → Claude 권고 + 사용자 확정. 교차검증 단계 없음. 최종 코드·커밋·푸시는 사용자.
- 옛 전략(GLES = Linux 주력, Vulkan deferred) **폐기**. 외부 메모리 renderer-backend-strategy 갱신 대상.
