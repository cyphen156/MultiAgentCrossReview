# AGENTS.md - MultiAgentCrossReview

Codex가 이 워크벤치에서 작업할 때 읽는 진입 문서입니다. 세부 규칙을 복제하지 않고, 반드시 읽어야 할 문서와 쓰기 전 확인 사항만 정합니다.

## 세션 시작

작업에 답하거나 도구를 실행하기 전에 다음 문서를 끝까지 읽습니다.

1. `Common/ROUTING.md`
2. `Common/SHARED_RULES.md`
3. `UserSettings/preferences.md` — 파일이 있을 때만

`UserSettings/preferences.md`는 이 워크벤치에만 적용합니다. 다른 워크벤치의 개인 설정을 가져오지 않습니다.

## 쓰기 전 확인

`Projects/projects.json`에 등록된 `sourceRepoRoot`는 기본적으로 보호된 읽기 전용 원본입니다.

파일 편집, 빌드, 커밋처럼 쓰기가 가능한 작업을 시작하기 전에 실제 대상 경로를 확인합니다. 사용자가 현재 요청에서 정확한 원본 저장소와 작업을 명시적으로 허용하지 않았다면 원본에 생성, 수정, 삭제, 빌드, 커밋 또는 푸시하지 않습니다.

워크벤치, `baseline/`, `edit/<agent>/`, 리뷰 상태, 동기화 도구 또는 에이전트 메모리에 대한 작업 권한은 원본 저장소 권한으로 이어지지 않습니다.

현재 상태는 live Git과 현재 프로젝트 문서에서 확인합니다. 규칙 파일, 미러, 이전 대화와 메모리는 현재 상태의 근거가 아닙니다.

## 조건부 문서

- 미러 범위나 `MirrorTargets.json`: `Common/MIRROR_SPEC.md`
- 정식 교차 검토 기록: `Reviews/README.md`
- 활성 프로젝트 규칙: `Projects/<active>/RULES.md`가 있을 때
- 개인 설정 안내: `UserSettings/README.md`
- 역할 참고: `Codex/ROLE.md`, `Claud/ROLE.md`

프로젝트 커밋 메시지나 DevLog를 작성하기 전에는 활성 프로젝트의 `RULES.md`를 확인합니다. 파일이 없다면 공통 규칙만 사용하고, 프로젝트 전용 제목 형식·경로·인코딩·템플릿을 추측하지 않습니다.
