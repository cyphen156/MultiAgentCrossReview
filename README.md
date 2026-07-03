# MultiAgentCrossReview

## Public / Private Boundary

This repository is the public MultiAgentCrossReview framework.

Public content belongs here:

- common workbench rules and routing docs;
- review templates under `Reviews/_TEMPLATE/**`;
- review process docs such as `Reviews/README.md`;
- review tooling such as `Reviews/run-review.ps1`;
- package/tooling code and public examples.

User-managed state does not belong in this public repository:

- actual `Reviews/<review-id>/` instances;
- user callbacks and user-derived review context;
- agent `REVIEW.md` and user `DECISION.md` records from real work;
- candidate artifacts produced during real state-backed review work;
- raw session transport data.

Actual review instances are personal working records. Keep them in the configured state repository/worktree, then pull public framework fixes from this repository as upstream changes.

`Packages/WorkbenchStateSync/` provides button-like pull/push for the mutable state that was removed from the public repository.

## Current Example

See `Examples/WorkbenchState/` for a sanitized, tracked example of the state layout that WorkbenchStateSync moves:

```text
UserSettings/preferences.md
Projects/ExampleProject/RULES.md
Reviews/2026-07-04_ExampleReview/README.md
Reviews/2026-07-04_ExampleReview/Claud/REVIEW.md
Reviews/2026-07-04_ExampleReview/Codex/REVIEW.md
Reviews/2026-07-04_ExampleReview/DECISION.md
```

Real files with that shape belong in the configured state repository/worktree, not under public `Reviews/<review-id>/`.

Minimal daily flow:

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
.\Reviews\run-review.ps1 -Topic 2026-07-04_ExampleReview -Status
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update review'
```

MultiAgentCrossReview는 여러 AI 에이전트가 같은 주제를 먼저 독립적으로 판단하고, 이후 서로의 주장과 근거를 교차 검증하도록 만드는 공개 검토 워크벤치입니다.

목표는 에이전트 사이의 합의를 빠르게 만드는 것이 아닙니다.  
독립 판단 사이의 불일치를 보존하고, 반박·수정·증거 확인·사용자 Callback을 거쳐 설계 결함과 불확실성을 드러내는 것이 목적입니다.

## 저장소 역할

| 저장소 | 역할 | 포함하는 것 |
|---|---|---|
| `MultiAgentCrossReview` | 공개 MIT 워크벤치 | 범용 규칙, 프로젝트 템플릿, WorkbenchStateSync 엔진, 리뷰 프로세스와 템플릿 |
| `MultiAgentWorkbenchStateSync` | 공개 MIT 예시 state repo | 사용자별 워크벤치 상태 저장소를 어떻게 구성하는지 보여주는 샘플 `UserSettings/`·`Projects/<name>/RULES.md`·`Reviews/<review-id>/` |
| [`AgentSessionSync`](https://github.com/cyphen156/AgentSessionSync) | 공개 MIT 세션 동기화 도구 | Codex·Claude 원본 세션 JSONL을 private session vault로 운반하는 Start/Finish 스크립트와 예시 |

이 저장소의 `Reviews/`는 공개 검토 기록 저장소가 아니라 프로세스 문서, 템플릿, 오케스트레이터를 담는 framework 영역입니다.  
원문 대화(JSONL)는 시스템 지침·도구 출력·절대경로까지 포함한 실행 로그라서 이 저장소에 두지 않고 `AgentSessionSync`가 따로 운반합니다.

`WorkbenchStateSync`와 `AgentSessionSync`는 둘 다 선택 기능입니다.  
한 대의 머신에서만 작업하거나 로컬 상태·대화 세션을 직접 관리한다면 쓰지 않아도 됩니다.  
여러 머신에서 같은 작업 상태를 이어가야 할 때만, 사용자가 직접 지정한 repository/worktree를 대상으로 경로를 설정해 사용합니다.

- 워크벤치 상태 동기화: `Packages/WorkbenchStateSync/`가 `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, 실제 `Reviews/<review-id>/**`를 동기화합니다.
- 세션 동기화: `AgentSessionSync`가 private session vault와 Codex·Claude 대화 JSONL을 동기화합니다.
- 실제 state repository 이름, URL, 절대경로는 공개 README에 고정하지 않습니다.

## 빠른 시작

```powershell
# 1) 대상 프로젝트 등록 (Projects/projects.example.json -> Projects/projects.json 로 복사 후 로컬 경로 수정)
#    { "projects": [ { "name": "ExampleProject", "sourceRepoRoot": "C:\\Path\\To\\ExampleProject", "engineSubdir": "ExampleProject" } ] }

# 2) 등록 프로젝트 동기화 — baseline 채우고 edit/Claud·edit/Codex 시드
.\sync.ps1                        # 매니페스트 전체
.\sync.ps1 -Project ExampleProject # 특정 프로젝트
.\sync.ps1 -ResetEdit All         # 편집 사본 강제 재시드

# 3) 선택: 여러 머신에서 워크벤치 상태를 공유해야 할 때만 WorkbenchStateSync 설정
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
# workbenchstatesync.config.psd1의 VaultRoot를 사용자가 지정한 state repo/worktree 경로로 수정
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Pull

# 4) 새 검토 주제 생성 + 진행
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-29_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Status   # 현재 상태
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Steps 8  # 끝까지
```

자세한 기록 규칙은 `Reviews/README.md`,  
범용 판단 규칙은 `Common/SHARED_RULES.md`,  
프로젝트별 규칙은 `Projects/<name>/RULES.md`를 참고합니다.

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

초기 판단은 상대 답변을 읽지 않습니다(오케스트레이터가 순서로 봉인).  
각 에이전트의 결론은 **단일 `REVIEW.md`**,  
최종 판정은 **단일 `DECISION.md`**에 담고, 결론이 바뀌면 그 파일을 갱신·커밋합니다.  
**현재 진실 = 작업트리의 파일, 변경 이력 = git** (번호 붙은 파일을 쌓지 않습니다).

## 저장소 구조

```text
CLAUDE.md / AGENTS.md       각 에이전트 진입점 (얇은 포인터)
Common/SHARED_RULES.md      범용 워크벤치 규칙 (SSOT)
Common/PROJECT_RULES.template.md  프로젝트별 규칙 템플릿 (공개)
UserSettings/               개인 설정 공간 (README만 공개, 하위 파일은 로컬 전용·gitignore)
Claud/ROLE.md               Claude 역할
Codex/ROLE.md               Codex 역할
Packages/WorkbenchStateSync/ user-managed workbench state sync engine (public package)

Projects/                   대상 프로젝트 코드 공간 (Projects/<name>/** 는 로컬 전용·gitignore)
  projects.example.json     공개 예시 등록부
  projects.json             로컬 등록부(gitignore) — sync 대상 프로젝트 목록
  <name>/
    RULES.md                프로젝트별 규칙 (로컬 전용·gitignore)
    baseline/               읽기전용 미러 (sync가 채움)
    edit/Claud, edit/Codex  에이전트별 코드 편집 사본

Reviews/                    공개 review framework + 로컬/동기화 대상 실제 검토 인스턴스
  <review-id>/
    README.md               주제 · 기준 커밋 · 범위 · 상태 · Callback
    Claud/REVIEW.md + artifacts/
    Codex/REVIEW.md + artifacts/
    DECISION.md             사용자 최종 판정
  _TEMPLATE/                새 검토 주제 템플릿
  run-review.ps1            반자동 교차검증 오케스트레이터

sync.ps1 / sync.cmd         projects.json 구동 미러 동기화
```

`Projects/<name>/` 하위(미러·편집본·빌드 산출물)는 전부 로컬 전용이라 `.gitignore`로 제외합니다.  
실제 등록부 `Projects/projects.json`도 로컬 전용이며, 공개 저장소에는 `Projects/projects.example.json`만 둡니다.  
대상 프로젝트 이름, 절대경로, 코드는 공개 저장소에 커밋하지 않습니다.

`Packages/WorkbenchStateSync/`는 공개 패키지이지만 실제 state repo 경로는 공개하지 않습니다.  
로컬 설정 파일(`Packages/WorkbenchStateSync/workbenchstatesync.config.psd1`, `WorkbenchStateSync.local.psd1`)은 gitignore 대상입니다.

## 규칙 계층

규칙은 성격에 따라 세 층으로 나눕니다.  
공개 레포에는 **범용 규칙과 템플릿만** 들어가고,  
특정 프로젝트·개인에 묶이는 규칙은 로컬 전용(gitignore)입니다.

| 층 | 위치 | 공개 | 내용 |
|---|---|---|---|
| 범용 워크벤치 | `Common/SHARED_RULES.md`, `Reviews/README.md` | 공개 | 독립판단→교차검증 절차, 범용 커밋 본문 구조, Reviews 운영 |
| 프로젝트별 | `Projects/<name>/RULES.md` (템플릿 `Common/PROJECT_RULES.template.md`) | 로컬 | 코드 스타일·인코딩·줄바꿈·아키텍처·DevLog 경로·커밋 제목 관례 |
| 개인 설정 | `UserSettings/` (안내 `UserSettings/README.md`) | 로컬 | 어조·검토 태도·사적 워크플로 등 사용자 설정 |

`run-review.ps1`은 활성 프로젝트(`projects.json` 첫 항목 또는 `-Project`)의 `RULES.md`를 범용 규칙과 함께 헤드리스 프롬프트에 주입합니다.  
`RULES.md`가 없으면 경고 후 범용 규칙만으로 진행합니다.  
즉, 헤드리스 리뷰 오케스트레이터는 누락된 프로젝트 룰에 대해 **fail-open**입니다.

커밋 메시지나 DevLog처럼 프로젝트별 형식이 있는 산출물은 활성 프로젝트의 `Projects/<name>/RULES.md`를 먼저 읽은 뒤 작성합니다.  
해당 파일이 없으면 기억으로 작성하지 않고, 누락된 프로젝트 룰을 먼저 보고합니다.  
즉, 대화형 커밋/DevLog 초안 작성은 **fail-closed**입니다.

프로젝트별 커밋 본문에서 `검증`, `다음 작업`은 자주 쓰는 선택 섹션일 뿐 닫힌 목록이 아닙니다.  
선택 섹션은 커밋 성격이나 사용자 명시 지시에 따라 제거, 추가, 이름 변경될 수 있습니다.

프로젝트별 DevLog는 작성 시각만으로 범위를 정하지 않습니다.  
각 프로젝트 룰이 이전 DevLog 이후의 대상 커밋 범위를 정합니다(예: auto-generated DevLog 커밋 자체는 요약 범위에서 제외).

## WorkbenchStateSync

`UserSettings/**/*.md`, `Projects/<name>/RULES.md`, 실제 `Reviews/<review-id>/**`는 공개 프레임워크에서 빠지는 사용자별 상태 데이터입니다.  
여러 머신이나 별도 저장소에서 이 상태를 이어 쓰려면 `Packages/WorkbenchStateSync/`를 사용해 사용자가 지정한 저장소와 동기화합니다.

원칙:

- 공개 MultiAgentCrossReview repo = 프로세스, 템플릿, 사용법, 패키지 도구.
- 상태 저장소 = 사용자가 지정한 repo/worktree. private일 수도 public일 수도 있지만, 담는 데이터 성격상 private를 권장합니다.
- 이 워크트리의 `UserSettings/`, `Projects/<name>/RULES.md`, `Reviews/<review-id>/` = 에이전트가 실제로 읽고 쓰는 materialized state.
- Claude/Codex memory = 캐시 또는 참고 맥락일 뿐 SSOT가 아닙니다.
- `Projects/<name>/baseline/**`와 `Projects/<name>/edit/**`는 WorkbenchStateSync 대상이 아닙니다.
- `Reviews/README.md`, `Reviews/_TEMPLATE/**`, `Reviews/run-review.ps1`은 공개 프레임워크 파일이므로 상태 저장소로 동기화하지 않습니다.

설정:

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

`workbenchstatesync.config.psd1`은 gitignore 대상입니다. 여기에 사용자가 지정한 상태 저장소 경로를 설정합니다.

예:

```powershell
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Pull
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Push
```

git pull/push까지 한 번에 처리하려면 래퍼를 씁니다(프로젝트 sync처럼 단순):

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
.\Packages\WorkbenchStateSync\Finish.ps1
```

작업표시줄/더블클릭용 `Start.cmd`·`Finish.cmd`도 있습니다. 상태 저장소에 원격이 없으면 `-SkipGitPull`/`-SkipGitPush`로 로컬만 동기화합니다.

WorkbenchStateSync는 다른 내용의 대상 파일을 조용히 덮어쓰지 않습니다.  
충돌 시 대상 파일을 `.bak`으로 백업하고 경고한 뒤 건너뛰며, `-Force`가 있을 때만 덮어씁니다.

기존 공개 예시 repo `MultiAgentPrivateRulesSync`는 WorkbenchStateSync 예시 저장소로 이름과 설명을 바꿔 재사용할 수 있습니다.

## 코드 차이와 증거

- 코드 수정은 `Projects/<name>/edit/Claud`·`edit/Codex`(에이전트별)에서 합니다. `edit/<agent>` vs `baseline` diff가 그 에이전트의 제안이며, 빌드/테스트 산출물도 거기에 떨어집니다(전부 로컬).
- 채택 후보 patch만 해당 에이전트의 `Reviews/<id>/<agent>/artifacts/`로 커밋해 공개 근거로 남깁니다.

## 현재 안전 경계

- 대상 프로젝트 원본은 이 저장소에서 수정하지 않습니다.
- `Projects/<name>/baseline`은 읽기전용 기준이고, 코드 수정은 `edit/{Claud,Codex}`에서만 합니다.
- 현재 결론은 단일 파일(REVIEW.md/DECISION.md), 변경 이력은 git이 보존합니다.
- 각 에이전트는 자기 폴더에만 씁니다(상대 폴더 읽기 전용). 최종 코드 적용·커밋·푸시는 사용자만, `DECISION.md` 기준.
- 로컬 인증정보, 에이전트 세션, IDE 상태, 빌드 산출물, 대상 프로젝트 코드는 이 저장소에 포함하지 않습니다.

## 참고

- 워크벤치 PowerShell 스크립트(`sync.ps1`, `Reviews/run-review.ps1`)는 Windows PowerShell 5.1의 한글 파싱을 위해 **UTF-8 BOM**으로 저장합니다 — 벗기지 마세요. (no-BOM은 대상 엔진 소스/DevLog의 규칙이지 워크벤치 툴링 규칙이 아닙니다.)
- 2026-06-28 이전 검토 주제는 옛 번호파일 레이아웃(레거시)으로 그대로 보존합니다.
