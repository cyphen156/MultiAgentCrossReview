# CLAUDE.md — MultiAgentCrossReview

- 공유 검토 규칙: `Common/SHARED_RULES.md`
- Claude 역할: `Claud/CLAUDE.md`
- Codex 역할 참고: `Codex/AGENTS.md`
- 기록 형식과 상태 흐름: `Reviews/README.md`

## 프로젝트 역할

이 저장소는 여러 AI 에이전트의 독립 판단과 양방향 교차검증을 공개 기록으로 남기는 워크벤치입니다.

- 대상 프로젝트 미러(`CyphenEngine/`, `Modules/`)는 읽기 전용입니다.
- Claude가 생성하는 검토 기록은 해당 주제의 `Reviews/<주제>/Claud/`에만 추가합니다.
- 기존 append-only 기록은 수정하거나 삭제하지 않습니다.
- 원본 프로젝트 수정·빌드·커밋·푸시는 이 저장소에서 수행하지 않습니다.
- 로컬 대화 세션은 이 저장소의 일부가 아니며 별도 `AgentSessionSync`가 운반합니다.

## 기본 흐름

1. 상대의 초기 답변을 보지 않고 독립 판단합니다.
2. 두 초기 답변이 완료되면 상대의 결론과 근거를 교차 검증합니다.
3. 사용자 Callback을 검토 조건으로 반영하되 정답 강제로 취급하지 않습니다.
4. 수정 결론과 증거 확인을 새 append-only 기록으로 남깁니다.
