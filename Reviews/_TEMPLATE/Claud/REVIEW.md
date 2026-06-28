---
Review-ID: <id>
Author: Claude
Baseline: <commit=...>
Session-Id:            # 선택 — 이 검토를 만든 대화 세션(AgentSessionSync) 라벨. 경로/내용 아님.
Status: Initial        # Initial -> Cross-reviewed -> Revised -> Evidence-checked
---

# Claude REVIEW — <주제>

> 단일 가변 파일. 단계가 진행되면 아래 섹션을 채우고 **커밋**한다.
> 변경 이력은 git이 보존한다(새 번호 파일을 만들지 않는다).
> 현재 진실 = 이 파일. 이력 = git log.

## 1. 독립 초기판단
상대 답을 보지 않고 작성. 근거: `파일경로 : 심볼` + DevLog 날짜.

Position: KEEP | REVISE

## 2. 교차검증 — Codex REVIEW 대상
`Codex/REVIEW.md` 를 읽고 검증.

Verdict: AGREE | OBJECT

## 3. 수정 결론
받은 교차검증 반영(유지 또는 수정).

Position: KEEP | REVISE

## 4. 증거 재확인
결론 근거가 baseline 미러 / DevLog 에 실제 존재하는지 재확인.
코드 산출물은 `Projects/<name>/edit/Claud` 에서 만들고, 채택 후보 patch만 `artifacts/` 로.

Evidence-Status: CONFIRMED | INSUFFICIENT
