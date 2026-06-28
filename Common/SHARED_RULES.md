# 공유 기본 규칙 (Claude + Codex 공동)

이 문서는 Claude와 Codex가 **공동 참고하는 독립 규칙 md**다.
기본 대화 컨텍스트 룰 · 코드 스타일 · 기본 참고 · DevLog 작성 포맷을 담는다.

> 참고 대상: 각 프로젝트의 `../Projects/<name>/baseline/` 미러 (Source·DevLog 등). 그 외는 리커넥션 제외.
> git 푸시/커밋 운영 내용은 다루지 않는다 — 커밋 메시지 예시는 GitHub 온라인에서 직접 본다.

---

## 1. 기본 컨텍스트 룰

- 두 에이전트(Claude·Codex)는 **읽기 전용**이다. 코드 수정/적용/커밋은 **사용자가 직접** 한다.
- 원본 레포(`C:\Project\CyphenEngine`)는 절대 건드리지 않는다. 참고본은 그 분리 스냅샷이다.
- 두 에이전트는 같은 질문에 대해 먼저 **서로의 답을 보지 않고 독립적으로 판단**한다.
- 두 초기 답변이 완료되면 곧바로 서로의 결론과 근거를 교차 검증한다.
- 사용자는 교차검증 중 언제든 선호 방향·근거·추가 질문·새 전제를 Callback으로 삽입할 수 있다.
- Codex는 구현 가능성에, Claude는 책임 경계와 보수적 검증에 조금 더 무게를 두지만 역할과 결론을 고정하지 않는다.
- 합의 자체가 목적이 아니라 불일치로 설계 결함을 드러내는 것이 목적이다.

## 2. 코드 스타일 (실제 코드로 검증됨)

- 줄바꿈 **LF**, 인코딩 **UTF-8**, 들여쓰기 **탭**.
- **Allman 브레이스** — 여는 중괄호는 항상 다음 줄. **한 줄 중괄호 금지.**
- **람다 금지** — JavaScript 코드 또는 외부 데이터 콜백 처리 시에만 허용.

## 3. 기본 참고 — 아키텍처 기준선

상세 출처: `../Projects/CyphenEngine/baseline/CyphenEngine/DevLog/폴더 기능 정리.txt`, 작업 방향: 같은 폴더 `Todos.txt`

- 계층: Build / Core / HAL / Platform / Engine / Runtime / Editor / Modules / pch.
- **Core는 OS API 직접 호출 금지** — 플랫폼/문자열 정책은 Build가 주입.
- 플랫폼별 구현(File/Path/Time/Logger IO)은 `Source/Platform/*` 아래.
- File = 단일 동기 I/O 공개 API + PlatformFile HAL / Path = 무상태 순수 문자열 유틸 / Time = Core 계산 + PlatformTime HAL.
- 런타임 사용자 코드에 raw IO를 무제한 노출하지 않는다.
- 과설계 경계: 이전 Skull 프로젝트의 stream-container식 과설계를 반복하지 않는다.
- 작업 순서: **구조 요약 → 작은 검토 가능한 패치 계획 → 작은 변경**. 큰 재작성 먼저 금지.

## 4. DevLog 작성 포맷

경로: `CyphenEngine/DevLog/yyyy/yy.mm.dd.txt` · 인코딩 UTF-8(BOM 없음) / LF / 들여쓰기 탭.

템플릿:
```
Date: YYYY-MM-DD
Branch: #1-프로젝트-리팩토링

작업 요약

진행한 커밋

주요 정리 내용

정리된 설계 기준

다음 작업
```

- 그날 커밋 전체 + 작업 사항을 총정리. 필요 시 `DevLog/Todos.txt`·`DevLog/폴더 기능 정리.txt`도 함께 수정.
- 줄 간격: **문단 전환 = 빈 줄 2개**, **번호 나열 항목 = 빈 줄 1개**.

## 5. 커밋 메시지 (참고만)

- 코드 커밋 제목: `#1_N [Category] 한글 제목` (들여쓰기 탭, 빈 줄은 1개 — git이 연속 빈 줄을 축약).
- DevLog 커밋: 영문 (Git Copilot 자동 생성).
- **상세 예시는 GitHub 온라인 커밋 이력에서 직접 확인** (로컬에 git 이력을 두지 않음).

## 6. 적대적 검토 교환소 (Reviews/)

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
