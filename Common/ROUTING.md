# 작업 라우팅

이 문서는 작업을 시작할 때 어떤 추가 문서를 읽어야 하는지 정합니다. 모든 작업에는 `Common/SHARED_RULES.md`가 적용되며, 아래 문서는 작업 범위에 따라 더합니다.

## 항상 적용할 것

- `UserSettings/preferences.md`가 있으면 항상 읽습니다. 그 밖의 `UserSettings/` 문서는 현재 작업에 필요할 때만 읽습니다.
- `Projects/projects.json`에 등록된 원본 저장소는 기본적으로 읽기 전용입니다. 쓰기 전에 대상 경로와 권한을 확인합니다.
- `baseline/`이 있으면 코드와 프로젝트 문서의 기본 참고면으로 사용합니다. 다만 현재 HEAD, 작업 트리 상태와 문서 최신성은 live Git에서 확인합니다.
- baseline은 미러 스펙에 포함된 파일만 담습니다. baseline에 없다는 이유만으로 원본에도 없다고 판단하지 않습니다.
- 이전 대화와 에이전트 메모리는 탐색 보조 자료일 뿐, 규칙·결정·현재 상태의 근거가 아닙니다.
- 공개 프레임워크와 개인 설정, 실제 검토 기록, 원문 대화 세션을 섞지 않습니다.
- 활성 프로젝트가 불분명하면 등록부의 첫 프로젝트를 습관적으로 고르지 않습니다. 사용자 요청과 실제 대상 경로로 판정하고, 프로젝트가 특정되지 않으면 공통 규칙만 사용합니다.

## 작업별 추가 문서

| 작업 | 추가로 읽을 문서 |
|---|---|
| 워크벤치 구조, 공개/비공개 경계, 검토 절차, `Reviews/`, `run-review.ps1` | 기록 형식이나 상태 흐름이 관련되면 `Reviews/README.md` |
| 등록 프로젝트의 코드, 문서, 규칙, 커밋, DevLog | `Projects/<name>/RULES.md`가 있을 때 |
| `baseline/`, `edit/` 또는 ProjectSync | `Common/MIRROR_SPEC.md`와 해당 프로젝트의 `MirrorTargets.json` |
| 개인 말투, 협업 방식, 안정적인 사용자 선호 | `UserSettings/preferences.md` |
| 로컬 인계, 머신 메모, 도구 등록부, 보류 패치 | 목적에 맞는 `UserSettings/` 파일 |
| 원문 세션 이동이나 다른 머신에서의 대화 연속성 | AgentSessionSync 또는 해당 Vault의 문서 |

## 적용 순서

1. 플랫폼 안전과 사용자가 현재 요청에서 정한 범위
2. `Common/SHARED_RULES.md`
3. `UserSettings/preferences.md`가 있을 때
4. 활성 프로젝트의 `RULES.md`가 있을 때
5. 정식 검토 중이라면 `Reviews/README.md`와 해당 리뷰 기록

프로젝트 규칙이 없더라도 작업은 계속할 수 있습니다. 이 경우 공통 커밋 본문 구조는 사용할 수 있지만 프로젝트 고유의 제목 형식, DevLog 경로, 인코딩과 관례는 만들어내지 않습니다.
