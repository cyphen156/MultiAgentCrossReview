# MultiAgentCrossReview

MultiAgentCrossReview는 여러 AI 에이전트가 같은 주제를 먼저 독립적으로 판단하고, 이후 서로의 주장과 근거를 교차 검증하도록 만드는 공개 검토 워크벤치입니다.

목표는 에이전트 사이의 합의를 빠르게 만드는 것이 아닙니다. 독립 판단 사이의 불일치를 보존하고, 반박·수정·증거 확인·사용자 Callback을 거쳐 설계 결함과 불확실성을 드러내는 것이 목적입니다.

## 두 저장소의 역할

| 저장소 | 역할 | 포함하는 것 |
|---|---|---|
| `MultiAgentCrossReview` | 사람이 읽고 재현하는 공개 검토 프로젝트 | 규칙, 독립 판단(REVIEW.md), 교차검증, 증거, Callback, 최종 결정(DECISION.md) |
| `AgentSessionSync` | 같은 로컬 대화를 다른 컴퓨터에서 재개하기 위한 운반 저장소 | Codex·Claude 원본 세션 JSONL, baton, 시작·종료 스크립트 |

이 저장소의 `Reviews/`가 공개 검토 기록의 기준입니다. 원문 대화(JSONL)는 시스템 지침·도구 출력·절대경로까지 포함한 실행 로그라서 이 저장소에 두지 않고 `AgentSessionSync`가 따로 운반합니다.

## 검토 흐름

```text
검토 주제(README) + 기준 커밋
    ↓
Codex 독립 판단 + Claude 독립 판단   (서로 안 봄)
    ↓
양방향 교차 검증
    ↓
각 에이전트의 수정 결론
    ↓
증거 재확인
    ↓
사용자 최종 결정 (DECISION.md)
```

초기 판단은 상대 답변을 읽지 않습니다(오케스트레이터가 순서로 봉인). 각 에이전트의 결론은 **단일 `REVIEW.md`**, 최종 판정은 **단일 `DECISION.md`**에 담고, 결론이 바뀌면 그 파일을 갱신·커밋합니다. **현재 진실 = 작업트리의 파일, 변경 이력 = git** (번호 붙은 파일을 쌓지 않습니다).

## 저장소 구조

```text
CLAUDE.md / AGENTS.md       각 에이전트 진입점 (얇은 포인터)
Common/SHARED_RULES.md      공유 규칙 (SSOT)
Claud/ROLE.md               Claude 역할
Codex/ROLE.md               Codex 역할

Projects/                   대상 프로젝트 코드 공간 (Projects/<name>/** 는 로컬 전용·gitignore)
  projects.json             등록부(추적) — sync 대상 프로젝트 목록
  <name>/
    baseline/               읽기전용 미러 (sync가 채움)
    edit/Claud, edit/Codex  에이전트별 코드 편집 사본

Reviews/                    검토 기록
  <review-id>/
    README.md               주제 · 기준 커밋 · 범위 · 상태 · Callback
    Claud/REVIEW.md + artifacts/
    Codex/REVIEW.md + artifacts/
    DECISION.md             사용자 최종 판정
  _TEMPLATE/                새 검토 주제 템플릿
  run-review.ps1            반자동 교차검증 오케스트레이터

sync.ps1 / sync.cmd         projects.json 구동 미러 동기화
```

`Projects/<name>/` 하위(미러·편집본·빌드 산출물)는 전부 로컬 전용이라 `.gitignore`로 제외하고, 등록부 `Projects/projects.json`만 추적합니다. 대상 프로젝트 코드는 공개 저장소에 커밋하지 않습니다.

## 빠른 시작

```powershell
# 1) 대상 프로젝트 등록 (Projects/projects.json)
#    { "projects": [ { "name": "CyphenEngine", "sourceRepoRoot": "C:\\Project\\CyphenEngine", "engineSubdir": "CyphenEngine" } ] }

# 2) 등록 프로젝트 동기화 — baseline 채우고 edit/Claud·edit/Codex 시드
.\sync.ps1                        # 매니페스트 전체
.\sync.ps1 -Project CyphenEngine  # 특정 프로젝트
.\sync.ps1 -ResetEdit All         # 편집 사본 강제 재시드

# 3) 새 검토 주제 생성 + 진행
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-29_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Status   # 현재 상태
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Steps 8  # 끝까지
```

자세한 기록 규칙은 `Reviews/README.md`, 공동 판단 규칙은 `Common/SHARED_RULES.md`를 참고합니다.

## 코드 차이와 증거

- 코드 수정은 `Projects/<name>/edit/Claud`·`edit/Codex`(에이전트별)에서 합니다. `edit/<agent>` vs `baseline` diff가 그 에이전트의 제안이며, 빌드/테스트 산출물도 거기에 떨어집니다(전부 로컬).
- 채택 후보 patch만 해당 에이전트의 `Reviews/<id>/<agent>/artifacts/`로 커밋해 공개 근거로 남깁니다.

## 현재 안전 경계

- 대상 프로젝트 원본(`C:\Project\CyphenEngine` 등)은 이 저장소에서 수정하지 않습니다.
- `Projects/<name>/baseline`은 읽기전용 기준이고, 코드 수정은 `edit/{Claud,Codex}`에서만 합니다.
- 현재 결론은 단일 파일(REVIEW.md/DECISION.md), 변경 이력은 git이 보존합니다.
- 각 에이전트는 자기 폴더에만 씁니다(상대 폴더 읽기 전용). 최종 코드 적용·커밋·푸시는 사용자만, `DECISION.md` 기준.
- 로컬 인증정보, 에이전트 세션, IDE 상태, 빌드 산출물, 대상 프로젝트 코드는 이 저장소에 포함하지 않습니다.

## 참고

- 워크벤치 PowerShell 스크립트(`sync.ps1`, `Reviews/run-review.ps1`)는 Windows PowerShell 5.1의 한글 파싱을 위해 **UTF-8 BOM**으로 저장합니다 — 벗기지 마세요. (no-BOM은 대상 엔진 소스/DevLog의 규칙이지 워크벤치 툴링 규칙이 아닙니다.)
- 2026-06-28 이전 검토 주제는 옛 번호파일 레이아웃(레거시)으로 그대로 보존합니다.
