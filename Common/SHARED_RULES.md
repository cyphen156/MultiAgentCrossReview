# 공유 기본 규칙 (Claude + Codex 공동)

이 문서는 Claude와 Codex가 **공동 참고하는 독립 규칙 md**다.
기본 대화 컨텍스트 룰 · 코드 스타일 · 기본 참고 · DevLog 작성 포맷을 담는다.

> 참고 대상: `../CyphenEngine/Source/` 와 `../CyphenEngine/DevLog/` 만 (그 외는 리커넥션 제외).
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

상세 출처: `../CyphenEngine/DevLog/폴더 기능 정리.txt`, 작업 방향: `../CyphenEngine/DevLog/Todos.txt`

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

두 에이전트의 제안·반박은 `../Reviews/` 에 **질문 단위 append-only**로 기록한다. 규칙: `../Reviews/README.md`.

- `Source`·`DevLog` = 불변 기준선 / `Reviews/` = 주장·반박 교환 공간.
- 각자 자기 폴더(`Codex/`·`Claud/`)에만 쓰고 상대 폴더는 읽기만. 반박은 새 번호 파일로 추가(기존 수정 금지).
- 두 초기 판단은 작성 중 서로에게 공개하지 않는다. 둘 다 완료되면 양방향 교차검증을 시작한다.
- 사용자 개입은 필수 승인 게이트가 아니라 `Callbacks/<Q>_C<NNN>_user.md` append-only 기록으로 추가하며, 이후 단계가 이를 함께 검토한다.
- 모든 기록에 메타데이터(Question-ID·Author·Responds-To·Supersedes·Status·Baseline). 결론이 바뀌어도 **옛 기록은 수정·삭제 금지** — 새 기록에 `Supersedes: <옛 파일>` 로 대체를 명시한다.
- 기록 파일명은 질문 단위로 분리(`<Q>_001_initial.md`, `<Q>_003_cross_review_codex.md` 등), Evidence도 `<Q>_E<NNN>_<author>.md` 로 질문별 분리.
- 새 검토는 `Reviews/_TEMPLATE/` 를 `<YYYY-MM-DD>_<주제>/` 로 복사해 시작.
- 최종 적용·원본 수정은 사용자만 (`Decision/<Q>_decision.md` 기준).
