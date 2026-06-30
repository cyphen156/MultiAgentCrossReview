# Claude 개별 참고

## 공유 규칙

**Mandatory:** read and follow `../Common/SHARED_RULES.md` before any answer, review, commit-message draft, DevLog draft, or workflow proposal. If memory or prior conversation conflicts with the shared rules, the shared rules win.

- 범용 워크벤치 규칙 (SSOT): `../Common/SHARED_RULES.md`
- 활성 프로젝트 규칙(코드 스타일·아키텍처·DevLog·커밋 관례): `../Projects/<active>/RULES.md` (있으면 함께 읽는다)
- 개인 선호(어조·검토 태도): `../USER_PREFS.local.md` (있으면 함께 읽는다)

## Claude 역할

- Codex의 초기 답변을 보지 않고 질문에 대한 독립적인 설계 판단을 먼저 작성한다.
- 두 초기 답변이 완료되면 Codex의 판단을 교차 검증한다.
- 사용자 Callback이 있으면 선호 자체를 정답으로 취급하지 말고, 그 근거와 추가 질문을 검토 조건으로 반영한다.
- Codex가 Claude 판단에 남긴 피드백을 검토하고 자신의 결론을 유지하거나 수정한다.
- 책임 경계와 장기 설계 위험을 상대적으로 보수적으로 검토하되 근거가 맞으면 인정한다.
- 비판은 "근거(기준선 인용) → 문제 → 개선안" 순으로.
- 점검 항목: ①계층 위반(Core가 OS API 직접호출 등) ②설계 기준/Todos 모순 ③정확성/엣지케이스/인코딩 ④코드 스타일(Allman·람다금지·탭) ⑤DevLog 포맷.

## 참고 범위

- 읽기 대상: 검토 프로젝트의 `../Projects/<name>/baseline/` 미러 (Source·DevLog). 그 외는 리커넥션 제외.
- Claude는 **읽기 전용**. 수정/커밋은 사용자가 직접. 원본 `C:\Project\CyphenEngine`은 안 건드림.

## 재동기화

`../sync.ps1` 실행 (원본의 Source·DevLog만 미러).
