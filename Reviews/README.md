# Reviews — 멀티 에이전트 설계 검토 로그

Codex와 Claude가 같은 주제에 먼저 독립적으로 판단하고, 서로의 결론을 양방향으로 교차 검증하는 공간이다.
`Projects/<name>/baseline/` 미러가 읽기 전용 기준선이고, `Reviews/`는 판단·반박·근거·사용자 개입·최종 결정을 보존한다.

## 기본 흐름

```text
주제(README) → 기준 커밋 고정
    ↓
Codex 독립 판단 + Claude 독립 판단   (서로 안 봄)
    ↓
양방향 교차 검증
    ↓
각자 결론 수정
    ↓
증거 재확인
    ↓
사용자 최종 결정 (DECISION.md)
```

- 초기 판단 작성 중에는 상대 판단을 보지 않는다(오케스트레이터가 순서로 봉인).
- 사용자는 언제든 Callback을 추가할 수 있다(선호 방향·근거·추가 질문·새 전제). 선호는 검토 조건이지 정답 강제가 아니다.

## 폴더 구조

```text
Reviews/
└── <YYYY-MM-DD>_<주제>/        (= review-id)
    ├── README.md               현재 상태 요약 · 기준 커밋 · 범위 · Callback 섹션
    ├── Claud/
    │   ├── REVIEW.md           Claude 판단 (단일 가변 파일)
    │   └── artifacts/          채택 후보 patch · 로그
    ├── Codex/
    │   ├── REVIEW.md           Codex 판단 (단일 가변 파일)
    │   └── artifacts/
    └── DECISION.md             사용자 최종 판정 (단일 가변 파일)
```

각 에이전트는 자기 폴더의 `REVIEW.md` 하나만 쓴다. 상대 폴더는 읽기 전용.

## 현재 진실 vs 이력 — append-only 폐기

- **현재 진실 = 작업트리의 파일.** 단계가 진행되면 `REVIEW.md`/`DECISION.md`를 갱신·덮어쓰고 **커밋**한다.
- **변경 이력 = git.** 단계마다 1커밋이 트레일이 된다. 번호 붙은 새 파일을 쌓지 않는다.
- 옛 모델(질문 단위 번호파일 + `Supersedes` 체인)은 **폐기**한다 — 실제로 한 번도 운영된 적이 없었고(모든 옛 기록이 `Supersedes: none`), 중간 파일을 현재로 오인하는 오염원이었다.

## 메타데이터 (REVIEW.md / DECISION.md 상단)

```text
Review-ID: 2026-06-28_Example
Author: Claude            # Claude | Codex | User
Baseline: commit=<sha>    # sync 가 기록한 기준 커밋 (Projects/<name>/baseline/.baseline)
Session-Id:               # 선택 — 만든 대화 세션(AgentSessionSync) 라벨. 경로/내용 아님.
Status: Initial           # Initial -> Cross-reviewed -> Revised -> Evidence-checked -> Decided
```

## 상태 흐름

```text
REVIEW.md   Initial -> Cross-reviewed -> Revised -> Evidence-checked
DECISION.md                                       -> Decided
```

각 전이 = 1커밋. Callback은 고정 단계가 아니라 어느 시점에든 `README.md`에 덧붙이며, 이후 단계가 함께 읽는다.

## 코드 차이는 Projects/ 에서

- 코드 수정은 `Projects/<name>/edit/Claud`·`edit/Codex`(에이전트별, gitignored)에서 한다.
- `edit/<agent>` vs `baseline` diff = 그 에이전트의 제안. 빌드/테스트 산출물도 거기(로컬).
- 채택 후보 patch만 해당 에이전트 `artifacts/`로 커밋(공개 근거).

## 실행

```powershell
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-28_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-28_Example          # 다음 단계 1회
.\Reviews\run-review.ps1 -Topic 2026-06-28_Example -Status  # 현재 상태
```

`run-review.ps1`은 각 단계에서 다음 차례 에이전트를 헤드리스(읽기전용·무도구)로 불러 그 `REVIEW.md`
단계 섹션을 채우고 커밋한다. (※ 단일 `REVIEW.md` 모델로 정렬 진행 중.)

## 운영 원칙

1. baseline 미러는 수정하지 않는다.
2. 현재 진실 = 파일, 이력 = git. 옛 파일을 쌓지 않는다.
3. 독립 초기판단에는 상대 판단·Callback을 넣지 않는다.
4. 교차검증 이후 단계에는 현재 주제의 Callback을 함께 읽는다.
5. 최종 코드 수정·커밋·푸시는 사용자만.
6. 2026-06-28 이전 토픽은 레거시(옛 번호파일) — 동결.
