Date: 2026-06-22
Question-ID: Q001
Author: Codex
Responds-To: pasted-text.txt implementation proposal
Supersedes: none
Status: Cross-Review-Complete
Baseline: 2026-06-22 workspace mirror

# 판정

수정 후 적용 가능. 현재 구현안 그대로는 계약 구현 마감으로 승인할 수 없다.

# 차단 사항

## 1. 구현 변경 재적재가 동작하지 않는다

제안은 `ModuleManager::Load()`에서 `binaryName`을 사용하도록 바꾸지만 `Refresh()`는 그대로 둔다. 현재 `Refresh()`는 같은 `moduleName`이 Enabled 상태로 남으면 기존 Record를 언로드하지 않고, 이후 `IsLoaded(moduleName)`이 true라 새 Binary도 로드하지 않는다.

```text
Renderer / Dx11 / CyphenRendererDx11
→ Renderer / Vulkan / CyphenRendererVulkan
```

위 변경은 Descriptor에만 반영되고 실제 적재 Binary는 DX11로 남는다.

필수 수정:

- `ModuleRecord`에 `implementationName`, `binaryName` 보관
- `Refresh()`에서 기존 Record와 새 Descriptor의 구현/Binary 비교
- 값이 달라지면 기존 Record 언로드 후 새 Binary 로드

## 2. ModuleManager 수명이 다시 Engine으로 들어갔다

제안의 `CyphenEngine::InitEngine()`은 `ModuleManager::Refresh()`를 호출하고 `ShutdownEngine()`은 `ModuleManager::Shutdown()`을 호출한다. 이는 최신 합의인 다음 경계를 위반한다.

```text
Launch/Application  Module 준비와 해제
Engine              준비된 Renderer 시스템 연결과 해제
```

필수 순서:

```text
Launch::StartEngineThread
  ModuleManager::Refresh
  CyphenEngine::InitEngine

CyphenEngine::InitEngine
  Time::Init
  Renderer::Initialize

CyphenEngine::ShutdownEngine
  Renderer::Shutdown

Launch::JoinEngineThread
  Engine Thread Join
  ModuleManager::Shutdown
```

Engine 초기화 실패 시 Launch가 `ModuleManager::Shutdown()`으로 롤백한다.

## 3. 개발 빌드 버전 계약이 누락됐다

최종 구현은 `RENDERER_MODULE_API_VERSION = 1`만 유지하여 앞서 합의한 `_DEBUG` 개발 버전 선택을 제거했다.

개발 버전을 이번 변경에 포함할지 명시적으로 확정해야 한다. 포함한다면 Debug와 Release가 같은 상수 정의를 공유하는 척하지 말고 전처리 분기가 실제 선택을 담당해야 한다.

# 중요 보강

## 4. implementationName이 write-only 상태다

Descriptor에 추가하지만 `Load()`와 Record, 조회, 변경 감지 어디에서도 사용하지 않는다. 필드가 계약 의미를 가지려면 최소한 현재 적재 구현을 Record에 보관하고 `Refresh()` 재적재 판단에 사용해야 한다.

## 5. binaryName 명시 검증이 없다

Enabled Descriptor에서 `binaryName`이 비어 있으면 `ModuleLoader::Load()`까지 잘못된 요청이 내려간다. `ModuleManager::Load()`에서 `implementationName` 정책과 `binaryName` 필수 여부를 먼저 검증해야 한다.

## 6. ModuleManager 공개 계약 주석이 이전 1:1 모델에 남는다

`ModuleDescriptor.h`만 고치고 `ModuleManager.h`의 책임 설명과 `Load/FindSymbol` 키 의미를 갱신하지 않는다. 다음 의미를 공개 계약에 기록해야 한다.

```text
Load/Unload/FindSymbol/IsLoaded argument = logical moduleName
ModuleLoader::Load argument              = binaryName
```

# 수용 사항

- `ModuleDescriptor`의 `moduleName / implementationName / binaryName` 분리
- `RendererModuleApi` 명칭 유지
- `Renderer`가 논리 모듈명 `Renderer`로 직접 심볼 조회
- 전체 로드 모듈 순회 제거
- 별도 bool 대신 `rendererType`으로 연결 상태 파생
- 빈 Initialize/Shutdown Backend 함수 미추가
- 실제 DLL/프로젝트/폴더명 유지

# 사소한 정리

`RENDERER_MODULE_NAME`은 포인터 상수보다 배열 상수가 더 직접적이다.

```cpp
constexpr CChar RENDERER_MODULE_NAME[] = CTEXT("Renderer");
```

포인터 형태도 컴파일은 가능하지만 배열은 저장소와 문자열 수명을 선언 자체가 소유하며 재대입 가능성도 제거한다.

# 최종 수정 조건

다음 조건을 모두 반영한 뒤 계약 구현 마감으로 재평가한다.

1. 구현/Binary 변경 시 재적재
2. ModuleManager 수명을 Launch/Application에 유지
3. 개발 빌드 버전 정책 복구 또는 명시적 제외 결정
4. implementationName을 Record와 변경 감지에 실제 사용
5. Enabled Descriptor의 Binary 검증
6. ModuleManager 공개 주석 갱신
