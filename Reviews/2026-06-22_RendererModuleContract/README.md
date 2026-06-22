# Renderer Module 계약 경계 검토

- **질문**: 논리 Module, 선택 구현, 네이티브 Binary, Renderer Backend 계약을 현재 기준선에서 분리한다.
- **범위**: ModuleDescriptor/ModuleManager/Renderer Backend/Launch/Engine 연결 계약과 완결 구현안
- **제외**: Manifest, 의존성 그래프, 설치 시스템, Render Thread, Command Queue, 실제 GPU 초기화
- **Baseline**: 2026-06-22 workspace mirror

## 현재 결론

- `Module`은 기능 패키지이며 DLL과 동일하지 않다.
- `ModuleDescriptor`는 논리 모듈명, 선택 구현명, 구현 Binary명을 분리한다.
- `ModuleManager`는 논리 모듈명으로 상태를 관리하고 `ModuleLoader`에는 Binary명만 전달한다.
- 같은 논리 모듈의 구현 또는 Binary가 바뀌면 기존 구현을 언로드하고 새 구현을 로드한다.
- `RendererModuleApi` 명칭은 유지한다. 선택 구현 Binary가 제공해도 계약의 소유 단위는 Renderer Module이다.
- `Renderer`는 로드된 `Renderer` 논리 모듈의 Module 계약을 직접 조회하며 전체 모듈을 순회하지 않는다.
- Module 준비는 Launch/Application, Renderer 시스템 연결·해제는 Engine 순서에 둔다.

## 기록 인덱스

| # | 파일 | Author | Responds-To | Status |
|---|---|---|---|---|
| 001 | Codex/Q001_001_contract_revision.md | Codex | user cross-review | Revision-Complete |
| 002 | Codex/Q001_002_naming_revision.md | Codex | Q001_001_contract_revision.md | Revision-Complete |
| 004 | Codex/Q001_004_cross_review_claude.md | Codex | pasted implementation proposal | Cross-Review-Complete |

## 최종 판정

현재 구현안은 수정 필요. 구현 변경 재적재와 Launch/Engine 수명 경계를 보강한 뒤 적용 판정. 대상 프로젝트 미러에는 적용하지 않음.
