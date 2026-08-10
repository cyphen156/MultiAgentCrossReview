# Reviews — 멀티 에이전트 설계 검토 로그

## Public / Private Boundary

`Reviews/` in the public MultiAgentCrossReview repository is a framework area, not a public archive of real review instances.

Public repository content:

- `Reviews/README.md`
- `Reviews/_TEMPLATE/**`
- `Reviews/run-review.ps1`

User-managed state repository content:

- `Reviews/<review-id>/README.md`
- `Reviews/<review-id>/*/REVIEW.md`
- `Reviews/<review-id>/DECISION.md`
- `Reviews/<review-id>/**/artifacts/**`
- user callbacks, user-derived context, and real review evidence from private work

Run real reviews in the configured state repository/worktree. Pull framework fixes from the public repository into that state workspace.

Codex와 Claude가 같은 주제에 먼저 독립적으로 판단하고, 서로의 결론을 양방향으로 교차 검증하는 공간이다.
`Projects/<name>/baseline/` 미러가 읽기 전용 기준선이고, `Reviews/`는 판단·반박·근거·사용자 개입·최종 결정을 보존한다.
이 단계 흐름은 정식 `Reviews/<review-id>/` 검토에만 적용한다. 일반 대화, 유지보수 감사, 사용자가 직접 전달한 교차검토에는 독립 초기판단 단계를 강제하지 않는다.

정식 검토를 시작하기 전에 baseline 마커와 필요한 증거 파일이 의도한 로컬 원본 스냅숏인지 확인한다. 마커의 커밋 SHA는 출처 보조 정보이며, baseline에는 동기화 당시의 미커밋 로컬 내용이 포함될 수 있다.
검토가 시작된 뒤에는 live 저장소가 전진하더라도 해당 검토의 baseline을 자동 갱신하지 않는다. 새 기준이 필요하면 새 baseline과 검토 범위를 명시적으로 결정한다.

## 기본 흐름

```text
주제(README) → baseline 스냅숏 마커 고정
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
    ├── README.md               현재 상태 요약 · baseline 스냅숏 마커 · 범위 · Callback 섹션
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
Baseline: <snapshot marker>    # sync 가 기록한 로컬 스냅숏 표식 (Projects/<name>/baseline/.baseline)
Project-Rules: <source>   # REVIEW.md 만. Projects/<name>/RULES.md 또는 shared-only (...)
Role-Source: <source>     # REVIEW.md 만. <Agent>/ROLE.md 또는 built-in-fallback
Session-Id:               # 선택 — 만든 대화 세션(AgentSessionSync) 라벨. 경로/내용 아님.
Status: Initial           # Initial -> Cross-reviewed -> Revised -> Evidence-checked -> Decided
```

`Project-Rules` 와 `Role-Source` 는 `run-review.ps1` 이 기록한다. 프로젝트 규칙 파일이나 역할 파일이
없어도 검토는 중단되지 않으며, 무엇으로 대체했는지가 이 두 줄에 남는다. 나중에 그 검토가 어떤
규칙 집합으로 수행됐는지 산출물만 보고 확인할 수 있어야 하기 때문이다.

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
단계 섹션을 채우고 커밋한다. 현재 모델은 에이전트별 단일 `REVIEW.md`를 갱신하고 이력을 git에 남긴다.

## 운영 원칙

1. baseline 미러는 수정하지 않는다.
2. 현재 진실 = 파일, 이력 = git. 옛 파일을 쌓지 않는다.
3. 독립 초기판단에는 상대 판단·Callback을 넣지 않는다.
4. 교차검증 이후 단계에는 현재 주제의 Callback을 함께 읽는다.
5. 최종 코드 수정·커밋·푸시는 사용자만.
6. 2026-06-28 이전 토픽은 레거시(옛 번호파일) — 동결.
