Date: 2026-06-22
Question-ID: Q001
Author: Codex
Responds-To: Q001_001_contract_revision.md
Supersedes: Q001_001_contract_revision.md
Status: Revision-Complete
Baseline: 2026-06-22 workspace mirror

# 명칭 수정 결론

`RendererModuleApi`를 `RendererBackendApi`로 변경하지 않는다.

논리 Module과 구현 Binary를 분리하는 것과 Module 계약의 이름을 Backend로 바꾸는 것은 별개의 문제다. `CyphenRendererDx11.dll`은 Renderer Module의 선택 구현 Binary이지만, DLL이 제공하는 계약은 여전히 Renderer Module 구현 계약이므로 기존 명칭을 유지한다.

유지할 이름:

```text
RendererModule.h
RendererModuleApi
RendererModuleResult
GetRendererModuleApi
GET_RENDERER_MODULE_API_NAME
Dx11RendererModule.cpp
```

유지할 경계:

```text
moduleName          Renderer
implementationName  Dx11
binaryName          CyphenRendererDx11
```

ModuleManager는 `moduleName`으로 논리 Module 상태를 관리하고, ModuleLoader에는 `binaryName`을 전달한다. Renderer는 논리 Module `Renderer`에 연결된 구현 Binary에서 `GetRendererModuleApi`를 조회한다.

`Q001_001_contract_revision.md`에서 제안한 Backend 명칭 변경과 관련 프로젝트 파일 rename은 폐기한다. ModuleDescriptor와 ModuleManager의 논리 Module/구현/Binary 분리, 구현 변경 시 재적재, Launch와 Engine의 수명 경계는 유지한다.
