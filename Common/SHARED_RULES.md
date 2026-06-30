# 공유 기본 규칙 (Claude + Codex 공동) — 범용 워크벤치

이 문서는 Claude와 Codex가 공동 참고하는 **범용 멀티에이전트 워크벤치 규칙**이다.
특정 대상 프로젝트의 코드 스타일·아키텍처·DevLog/커밋 관례는 여기 두지 않고,
활성 프로젝트의 `../Projects/<name>/RULES.md`(로컬 전용)에 둔다.

**Mandatory shared rules:** Claude and Codex must read and follow this file before answering, reviewing, drafting commit messages, drafting DevLogs, or proposing workflow changes. If memory, prior chat, local habit, or another non-SSOT note conflicts with this file, this file wins.

규칙 계층:

- 프로젝트별 규칙(코드 스타일·아키텍처·DevLog 경로·커밋 제목 관례): `../Projects/<active>/RULES.md` (로컬, 템플릿: `./PROJECT_RULES.template.md`)
- 개인 선호(어조·검토 태도 등): `../USER_PREFS.local.md` (로컬, 있으면 함께 읽는다)
- 기록 형식·상태 흐름·운영 원칙: `../Reviews/README.md`

> 참고 대상: 각 프로젝트의 `../Projects/<name>/baseline/` 미러 (Source·DevLog 등). 그 외는 리커넥션 제외.
> git 푸시/커밋 운영 내용은 다루지 않는다 — 커밋/DevLog 문안 작성 포맷만 고정한다.

---

## 1. 기본 컨텍스트 룰

- 두 에이전트(Claude·Codex)는 **읽기 전용**이다. 코드 수정/적용/커밋은 **사용자가 직접** 한다.
- 대상 프로젝트의 원본 레포(`../Projects/projects.json` 의 `sourceRepoRoot`)는 절대 건드리지 않는다. baseline 미러는 그 분리 스냅샷이다.
- 두 에이전트는 같은 질문에 대해 먼저 **서로의 답을 보지 않고 독립적으로 판단**한다.
- 두 초기 답변이 완료되면 곧바로 서로의 결론과 근거를 교차 검증한다.
- 사용자는 교차검증 중 언제든 선호 방향·근거·추가 질문·새 전제를 Callback으로 삽입할 수 있다.
- Codex는 구현 가능성에, Claude는 책임 경계와 보수적 검증에 조금 더 무게를 두지만 역할과 결론을 고정하지 않는다.
- 합의 자체가 목적이 아니라 불일치로 설계 결함을 드러내는 것이 목적이다.

## 2. 커밋 작성 포맷 (범용 구조)

코드 커밋 본문은 아래 범용 구조를 기본으로 쓴다. **제목 형식·카테고리·들여쓰기 등 프로젝트별 관례는 `../Projects/<active>/RULES.md` 를 따른다.**

본문:
```
변경 요약
	이번 커밋에서 해결한 문제와 방향을 2~4문장으로 정리한다.
	작업 범위에 포함되지 않은 큰 후속 과제는 여기서 완료처럼 쓰지 않는다.

상세 변경 내용
	1. 첫 번째 변경 묶음
		구체적으로 바뀐 책임, 경계, 파일군, 동작을 쓴다.

	2. 두 번째 변경 묶음
		검증 가능한 코드 변화 위주로 쓴다.
```

선택 본문(+@):
```
검증
	실제로 수행한 빌드/테스트/실행 결과를 쓴다.
	PASS/FAIL 수치나 실패 지점은 원문 값을 유지한다.

다음 작업
	이번 커밋에서 끝나지 않은 작업만 쓴다.
	이미 구현된 항목을 다음 작업으로 남기지 않는다.
```

- 필수 구성요소는 제목, `변경 요약`, `상세 변경 내용`이다.
- `검증`, `다음 작업`은 커밋 내용에 실제 검증 결과나 남은 작업을 함께 기록해야 할 때만 붙이는 선택 구성요소다.
- 빈 줄은 섹션 사이 1개를 기본으로 둔다. git이 연속 빈 줄을 축약할 수 있다.
- 검증하지 않은 내용을 검증 섹션에 쓰지 않는다. 추정은 본문에 넣지 않는다.

## 3. DevLog 작성 포맷 (범용 원칙)

DevLog 의 구체 경로·인코딩·템플릿·줄간격은 프로젝트별(`../Projects/<active>/RULES.md`)이다. 여기서는 범용 원칙만 고정한다.

- 날짜는 파일 작성 시각이 아니라 **연속 작업 단위의 기준일**을 따른다. 자정을 넘겨 정리해도 같은 연속 작업이면 기준일의 DevLog에 기록한다.
- 그날 커밋 전체 + 작업 사항을 총정리한다.

## 4. 적대적 검토 교환소 (Reviews/)

두 에이전트의 판단·반박은 `../Reviews/<review-id>/` 에 기록한다. 상세 규칙: `../Reviews/README.md`.

- baseline 미러(`Projects/<name>/baseline/`) = 불변 기준선 / `Reviews/` = 판단·반박·결정 공간.
- 각자 자기 폴더(`Claud/`·`Codex/`)의 **단일 `REVIEW.md`**만 쓰고 상대 폴더는 읽기만.
- **현재 진실 = 작업트리의 파일, 변경 이력 = git.** 결론이 바뀌면 `REVIEW.md`/`DECISION.md`를 덮어쓰고 커밋한다. 번호 붙은 새 파일을 쌓지 않는다(옛 append-only·Supersedes 모델 폐기 — 한 번도 운영된 적 없음).
- 두 초기판단은 작성 중 서로에게 공개하지 않는다(오케스트레이터가 순서로 봉인). 둘 다 끝나면 양방향 교차검증.
- 코드 수정은 `Projects/<name>/edit/Claud`·`edit/Codex`(에이전트별, gitignored)에서. 채택 후보 patch만 해당 에이전트 `artifacts/`로 커밋.
- 사용자 개입(Callback)은 검토 `README.md`의 Callback 섹션에 시간순으로 덧붙인다. 앵커는 선택. 사용자 선호는 검토 조건이지 정답 강제가 아니다.
- 메타데이터: `Review-ID·Author·Baseline·Status`(+선택 `Session-Id`). baseline은 sync가 기록한 기준 커밋.
- 새 검토 = `Reviews/_TEMPLATE/`를 `<YYYY-MM-DD>_<주제>/`로 복사. 최종 적용·원본 수정은 사용자만(`DECISION.md` 기준).
- 2026-06-28 이전 토픽은 옛 번호파일 레이아웃(레거시 동결). 새 모델은 이후 검토에만 적용.
