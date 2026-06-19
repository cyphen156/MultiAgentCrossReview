# Reviews - 멀티 에이전트 설계 검토 로그

Codex와 Claude가 같은 질문에 먼저 독립적으로 답하고, 서로의 결론을 양방향으로 교차 검증하는 공간이다.
`CyphenEngine/Source`와 `DevLog`는 읽기 전용 기준선이며, `Reviews/`는 질문·판단·반박·근거·사용자 개입·최종 판정을 보존한다.

## 기본 흐름

```text
사용자 질문
    ↓
Codex 초기 답변 + Claude 초기 답변
    ↓
양방향 교차 검증
    ↓
각자 결론 수정
    ↓
증거 재확인
    ↓
사용자 최종 판정
```

- 초기 답변 작성 중에는 상대 답변을 공개하지 않는다.
- 두 초기 답변이 완료되면 별도 승인 없이 교차 검증으로 진행한다.
- 사용자는 교차 검증 중 언제든 Callback을 추가할 수 있다.
- Callback에는 선호 방향, 선호 근거, 추가 질문, 새 전제를 기록할 수 있다.
- Callback 이후의 에이전트 단계는 해당 기록을 함께 읽는다.
- 사용자 선호는 검토 조건이지 정답 강제가 아니다.

## 폴더 구조

```text
Reviews/
└── <YYYY-MM-DD>_<주제>/
    ├── README.md
    ├── Questions/
    │   └── Q001.md
    ├── Codex/
    │   ├── Q001_001_initial.md
    │   ├── Q001_004_cross_review_claude.md
    │   ├── Q001_005_revision.md
    │   └── Q001_007_evidence_check.md
    ├── Claud/
    │   ├── Q001_002_initial.md
    │   ├── Q001_003_cross_review_codex.md
    │   ├── Q001_006_revision.md
    │   └── Q001_008_evidence_check.md
    ├── Callbacks/
    │   └── Q001_C001_user.md
    ├── Evidence/
    │   ├── Q001_E001_codex.md
    │   └── Q001_E002_claude.md
    └── Decision/
        └── Q001_decision.md
```

각 에이전트는 자기 폴더에만 기록한다. 질문 ID로 상태를 분리하고 번호로 전체 시간순을 추적한다.

## 메타데이터

모든 append-only 기록 상단에 다음 항목을 둔다.

```text
Date: 2026-06-15
Question-ID: Q001
Author: Codex
Responds-To: none
Supersedes: none
Status: Initial-Complete
Baseline: 2026-06-15T17:11 sync
```

기존 기록은 수정하거나 삭제하지 않는다. 결론이 바뀌면 새 기록의 `Supersedes`로 이전 파일을 가리킨다.
주제별 `README.md`만 현재 상태를 요약하기 위해 갱신할 수 있다.

## 상태 흐름

```text
001 Codex 독립 판단
002 Claude 독립 판단
003 Claude가 Codex 판단 교차 검증
004 Codex가 Claude 판단 교차 검증
005 Codex 수정 결론
006 Claude 수정 결론
007 Codex 증거 재확인
008 Claude 증거 재확인
Decision 사용자 최종 판정
```

Callback은 고정 단계가 아니다. 어느 시점에든 추가할 수 있으며, 추가된 뒤 실행되는 단계부터 프롬프트에 포함된다.
두 답변을 같은 화면에서 비교하는 앱에서는 교차 검증 또는 수정 단계의 한 쌍을 시작하기 전에 Callback을 확정하는 편이 양쪽에 같은 조건을 제공한다.

## 실행

```powershell
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-15_FileSystem -Recurse

.\Reviews\run-review.ps1 -Topic 2026-06-15_FileSystem
.\Reviews\run-review.ps1 -Topic 2026-06-15_FileSystem -Steps 2
.\Reviews\run-review.ps1 -Topic 2026-06-15_FileSystem -DryRun

.\Reviews\run-review.ps1 -Topic 2026-06-15_FileSystem `
  -AddCallback `
  -Preference PreferCodex `
  -PreferenceReason "현재 패치 범위가 더 작음" `
  -CallbackText "Core와 Platform 경계 위반 가능성을 다시 확인할 것"

.\Reviews\run-review.ps1 -Topic 2026-06-15_FileSystem -Steps 6
```

`-Preference` 값은 `None`, `PreferCodex`, `PreferClaude`, `Merge`, `RejectBoth` 중 하나다.
다른 질문은 `-Question Q002`로 지정한다.

## 운영 원칙

1. Source와 DevLog는 수정하지 않는다.
2. 질문·답변·반박·Callback·Evidence·Decision은 append-only로 보존한다.
3. 독립 초기 답변에는 상대 답변, 가변 README, 에이전트 생성 Evidence, Callback을 넣지 않는다.
4. 교차 검증 이후 단계에는 현재 질문의 Callback만 포함한다.
5. 최종 코드 수정·커밋·푸시는 사용자만 수행한다.
6. 최대 8회 에이전트 호출이 발생하므로 중요한 설계 질문에만 사용한다.

Codex는 `codex exec` read-only ephemeral 모드로, Claude는 `claude -p --safe-mode`로 호출한다.
`sync.ps1`은 실제 동기화 시점을 `CyphenEngine/.baseline`에 기록한다.
