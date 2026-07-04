# MultiAgentCrossReview

MultiAgentCrossReview는 여러 AI 에이전트가 같은 주제를 먼저 독립적으로 판단하고, 이후 서로의 주장과 근거를 교차 검증하도록 만드는 공개 검토 워크벤치입니다.

목표는 에이전트 사이의 합의를 빠르게 만드는 것이 아닙니다.  
독립 판단 사이의 불일치를 보존하고, 반박·수정·증거 확인·사용자 Callback을 거쳐 설계 결함과 불확실성을 드러내는 것이 목적입니다.

이 저장소는 **실제 검토 기록의 공개 아카이브가 아닙니다.** 검토 프로세스, 템플릿, 도구, 정제된 실예시만 둡니다.  
실제 검토 기록과 사용자별 설정은 사용자가 직접 지정한 **상태 저장소(state repository)**에 둡니다.

## 저장소 역할

| 저장소 | 역할 | 포함하는 것 |
|---|---|---|
| `MultiAgentCrossReview` | 공개 MIT 워크벤치 | 범용 규칙, 프로젝트 템플릿, 검토 오케스트레이터(`run-review.ps1`), 검토 템플릿(`_TEMPLATE`), WorkbenchStateSync 도구 사본, 정제된 실예시(`Examples/`) |
| [`MultiAgentWorkbenchStateSync`](https://github.com/cyphen156/MultiAgentWorkbenchStateSync) | 공개 MIT 도구 | 사용자 관리 워크벤치 상태(`UserSettings/`·`Projects/<name>/RULES.md`·`Reviews/<review-id>/`)를 사용자 지정 상태 저장소와 동기화하는 독립 도구 |
| [`AgentSessionSync`](https://github.com/cyphen156/AgentSessionSync) | 공개 MIT 세션 동기화 도구 | Codex·Claude 원본 세션 JSONL을 private session vault로 운반하는 Start/Finish 스크립트와 예시 |

공개 저장소는 프로세스·템플릿·도구·정제된 실예시만 두고, 실제 검토 인스턴스(`Reviews/<review-id>/`)는 사용자 관리 상태로 취급합니다.  
원문 대화(JSONL)는 시스템 지침·도구 출력·절대경로까지 포함한 실행 로그라서 이 저장소에 두지 않고 `AgentSessionSync`가 따로 운반합니다.

`WorkbenchStateSync`와 `AgentSessionSync`는 둘 다 선택 기능입니다.  
한 대의 머신에서만 작업하거나 로컬 상태·대화 세션을 직접 관리한다면 쓰지 않아도 됩니다.  
여러 머신에서 같은 작업 상태를 이어가야 할 때만, 사용자가 직접 만든 **상태 저장소**를 대상으로 경로를 설정해 사용합니다.

- 상태 동기화: `Packages/WorkbenchStateSync/`가 상태 저장소와 `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, `Reviews/<review-id>/**`를 동기화합니다.
- 세션 동기화: `AgentSessionSync`가 private session vault와 Codex·Claude 대화 JSONL을 동기화합니다.
- 실제 상태 저장소 이름, URL, 절대경로는 공개 README에 고정하지 않습니다.

## 원클릭 Start / Finish

루트의 `Start.ps1` / `Finish.ps1`는 `Packages/` 아래의 **외부·선택 sync 어댑터**를 한 번에 실행하는 통합 버튼입니다.
멤버십은 별도 목록 파일이 아니라 **폴더 위치**로 정합니다 — `Packages/<name>/`에 `Start.ps1`이 있으면 실행 대상입니다. 새 sync 어댑터는 `Packages/`에 넣는 순간 포함되고, 빼면 제외됩니다.

현재 `Packages/` (원클릭 대상):

- `Packages/WorkbenchStateSync/` — 외부 `MultiAgentWorkbenchStateSync` 호출 어댑터
- `Packages/AgentSessionSync/` — 외부 `AgentSessionSync` 호출 어댑터

두 어댑터 모두 외부 도구(ToolRoot)를 clone·설정하기 전에는 **skip**합니다(에러 아님).

`ProjectSync`는 `Packages/` **밖**의 내장·필수 단방향 미러(루트 `sync.ps1`)라서 원클릭에 딸려 들어가지 않습니다. 프로젝트 미러가 필요할 때만 수동으로 실행합니다.

```powershell
.\Start.ps1
.\Finish.ps1
```

작업표시줄 고정용 Windows `.lnk` 바로가기는 로컬에서 생성합니다.

```powershell
.\Create-Shortcuts.ps1
```

생성된 `Shortcuts/` 폴더는 gitignore 대상입니다.

특정 패키지만 실행할 수도 있습니다.

```powershell
.\Start.ps1 -Include WorkbenchStateSync
.\Finish.ps1 -Include AgentSessionSync
```

루트 버튼은 패키지별로 계속 진행한 뒤 `Package | Action | Result | Reason` 요약표를 출력합니다. 일부 패키지가 실패해도 나머지를 시도하고, 마지막에 실패가 하나라도 있으면 non-zero exit code를 반환합니다.

프로젝트 미러 동기화는 별도로 실행합니다.

```powershell
.\ProjectSync\Start.ps1
.\ProjectSync\Start.ps1 -Project ExampleProject
.\ProjectSync\Start.ps1 -ResetEdit All
```

## 빠른 시작

```powershell
# 1) 대상 프로젝트 등록 (Projects/projects.example.json -> Projects/projects.json 로 복사 후 로컬 경로 수정)
#    { "projects": [ { "name": "ExampleProject", "sourceRepoRoot": "C:\\Path\\To\\ExampleProject", "engineSubdir": "ExampleProject" } ] }

# 2) 등록 프로젝트 동기화 — baseline 채우고 edit/Claud·edit/Codex 시드
.\sync.ps1                        # 매니페스트 전체
.\sync.ps1 -Project ExampleProject # 특정 프로젝트
.\sync.ps1 -ResetEdit All         # 편집 사본 강제 재시드

# 3) 선택: 여러 머신에서 상태 저장소를 공유해야 할 때만 WorkbenchStateSync 설정
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
# workbenchstatesync.config.psd1의 VaultRoot를 사용자가 만든 상태 저장소 clone 경로로 수정
.\Packages\WorkbenchStateSync\Start.ps1   # 상태 저장소 -> 현재 워크트리로 materialize

# 4) 새 검토 주제 생성 + 진행
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-29_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Status   # 현재 상태
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Steps 8  # 끝까지

# 5) 선택: 작업한 상태를 상태 저장소로 되돌려 보내기
.\Packages\WorkbenchStateSync\Finish.ps1  # 워크트리 상태 -> 상태 저장소 commit/push
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
**현재 진실 = 작업트리의 파일, 변경 이력 = 상태 저장소의 git** (번호 붙은 파일을 쌓지 않습니다).

## 저장소 구조

```text
CLAUDE.md / AGENTS.md       각 에이전트 진입점 (얇은 포인터)
Common/SHARED_RULES.md      범용 워크벤치 규칙 (SSOT)
Common/PROJECT_RULES.template.md  프로젝트별 규칙 템플릿 (공개)
UserSettings/               개인 설정 공간 (README만 공개, 하위 파일은 로컬 전용·gitignore)
Claud/ROLE.md               Claude 역할
Codex/ROLE.md               Codex 역할
Start.ps1 / Finish.ps1      Packages/* 외부 sync 어댑터 통합 원클릭 (폴더=멤버십)
Create-Shortcuts.ps1        통합 Start/Finish 작업표시줄용 .lnk 생성기
Packages/WorkbenchStateSync/  외부 상태 sync 도구 호출 어댑터 (외부 레포 canonical)
Packages/AgentSessionSync/    외부 세션 sync 도구 호출 어댑터 (외부 레포 canonical)
ProjectSync/                내장·필수 프로젝트 미러 버튼 (루트 sync.ps1 감쌈, 원클릭 밖)
Examples/                   정제된 공개 실예시 (상태의 형태를 보여줌)

Projects/                   대상 프로젝트 코드 공간 (Projects/<name>/** 는 로컬 전용·gitignore)
  projects.example.json     공개 예시 등록부
  projects.json             로컬 등록부(gitignore) — sync 대상 프로젝트 목록
  <name>/
    RULES.md                프로젝트별 규칙 (로컬 전용·gitignore)
    baseline/               읽기전용 미러 (sync가 채움)
    edit/Claud, edit/Codex  에이전트별 코드 편집 사본

Reviews/                    검토 프레임워크 (공개)
  README.md                 검토 기록 규칙
  _TEMPLATE/                새 검토 주제 템플릿
  run-review.ps1            반자동 교차검증 오케스트레이터
  <review-id>/              실제 검토 인스턴스 (로컬 전용·gitignore, 상태 저장소로 동기화)
    README.md               주제 · 기준 커밋 · 범위 · 상태 · Callback
    Claud/REVIEW.md + artifacts/
    Codex/REVIEW.md + artifacts/
    DECISION.md             사용자 최종 판정

sync.ps1 / sync.cmd         projects.json 구동 미러 동기화 (ProjectSync가 감쌈)
```

`Projects/<name>/` 하위(미러·편집본·빌드 산출물)는 전부 로컬 전용이라 `.gitignore`로 제외합니다.  
실제 등록부 `Projects/projects.json`도 로컬 전용이며, 공개 저장소에는 `Projects/projects.example.json`만 둡니다.  
대상 프로젝트 이름, 절대경로, 코드는 공개 저장소에 커밋하지 않습니다.

실제 검토 인스턴스 `Reviews/<review-id>/`도 로컬 전용(`.gitignore`)이며, 공개 저장소에는 `Reviews/README.md`·`_TEMPLATE/`·`run-review.ps1`과 `Examples/`의 정제된 실예시만 둡니다.  
`Packages/WorkbenchStateSync/`는 공개 패키지이지만 실제 상태 저장소 경로는 공개하지 않습니다.  
로컬 설정 파일(`Packages/WorkbenchStateSync/workbenchstatesync.config.psd1`, `WorkbenchStateSync.local.psd1`, `Packages/AgentSessionSync/agentsessionsync.config.psd1`, `AgentSessionSync.local.psd1`)은 gitignore 대상입니다.

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

`UserSettings/**/*.md`, `Projects/<name>/RULES.md`, 실제 `Reviews/<review-id>/`는 공개 저장소에 커밋하지 않는 로컬 상태입니다.  
여러 머신에서 이 상태를 이어 써야 할 때만 `Packages/WorkbenchStateSync/`를 사용해 사용자가 직접 만든 상태 저장소와 동기화합니다.

원칙:

- 상태 저장소 = 워크벤치 개인 상태의 SSOT (룰·설정·실제 검토 기록).
- 이 워크트리의 `UserSettings/`, `Projects/<name>/RULES.md`, `Reviews/<review-id>/` = 에이전트가 실제로 읽고 쓰는 materialized copy.
- Claude/Codex memory = 캐시 또는 참고 맥락일 뿐 SSOT가 아닙니다.
- `Projects/<name>/baseline/**`와 `Projects/<name>/edit/**`는 동기화 대상이 아닙니다.
- 공개 프레임워크 파일(`README.md`, `Reviews/README.md`, `Reviews/_TEMPLATE/**`, `Reviews/run-review.ps1`)은 동기화 대상이 아닙니다. 공개 안내·도구는 공개 repo에 남기고, 상태 저장소에는 실제 상태 데이터만 둡니다.

이 도구는 매니페스트 기반의 기계적 동기화입니다. 대상 원격이 비공개인지 공개인지는 도구가 판단하지 않으며, **무엇을 올릴지**는 위 포함/제외 목록이, **어디로 올릴지**는 사용자 설정이 정합니다. Push 시 토큰류 유출을 막기 위한 시크릿 스캔만 안전장치로 남아 있습니다.

설정:

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

`workbenchstatesync.config.psd1`은 gitignore 대상입니다. 여기에 사용자의 상태 저장소 경로를 지정합니다.

예:

```powershell
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Pull   # 상태 저장소 -> 현재 워크트리
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Push   # 현재 워크트리 -> 상태 저장소
```

git pull/push까지 한 번에 처리하려면 래퍼를 씁니다(프로젝트 sync처럼 단순):

```powershell
.\Packages\WorkbenchStateSync\Start.ps1    # 상태 저장소 git pull -> 워크트리로 materialize
.\Packages\WorkbenchStateSync\Finish.ps1   # 워크트리 상태 -> 상태 저장소 commit/push
```

작업표시줄 고정용 `.lnk`는 `Packages/WorkbenchStateSync/Create-Shortcuts.ps1`로 생성합니다. 생성된 `Shortcuts/` 폴더는 gitignore 대상입니다. 상태 저장소에 원격이 없으면 `-SkipGitPull`/`-SkipGitPush`로 로컬만 동기화합니다.

WorkbenchStateSync는 다른 내용의 대상 파일을 조용히 덮어쓰지 않습니다.  
충돌 시 대상 파일을 `.bak`으로 백업하고 경고한 뒤 건너뛰며, `-Force`가 있을 때만 덮어씁니다.

동기화 도구 자체는 별도 MIT 공개 repo [MultiAgentWorkbenchStateSync](https://github.com/cyphen156/MultiAgentWorkbenchStateSync)로도 제공합니다.  
SSOT는 이 워크벤치의 `Packages/WorkbenchStateSync/`이며, 독립 공개 repo는 여기서 발행하는 배포 대상입니다.
실제 개인 상태 저장소는 사용자가 직접 **상태 저장소**로 만들어 경로를 지정합니다.

## AgentSessionSync 패키지 어댑터

`Packages/AgentSessionSync/`는 원문 대화 세션 JSONL을 옮기는 별도 공개 도구 `AgentSessionSync`를 이 워크벤치의 버튼 체계에 연결하는 얇은 어댑터입니다.
SSOT는 외부 `AgentSessionSync` repo이고, 이 패키지는 로컬 `ToolRoot`의 `Start.ps1` / `Finish.ps1` 존재를 확인한 뒤 공통 옵션을 넘겨 호출합니다. 이 워크벤치 안에는 세션 동기화 로직을 복제하지 않습니다.

```powershell
Copy-Item .\Packages\AgentSessionSync\agentsessionsync.config.example.psd1 .\Packages\AgentSessionSync\agentsessionsync.config.psd1
```

`agentsessionsync.config.psd1`의 `ToolRoot`를 로컬 `AgentSessionSync` clone 경로로 지정합니다.

```powershell
.\Packages\AgentSessionSync\Start.ps1
.\Packages\AgentSessionSync\Finish.ps1
```

설정이 없거나 `ToolRoot`의 대상 스크립트가 없으면 루트 `Start.ps1` / `Finish.ps1`에서 이 패키지는 skip됩니다.

## ProjectSync 패키지

`ProjectSync/`(루트, `Packages/` 밖)는 기존 `sync.ps1`를 버튼화한 **내장·필수 단방향 미러**입니다.

```powershell
.\ProjectSync\Start.ps1
.\ProjectSync\Start.ps1 -Project ExampleProject
.\ProjectSync\Start.ps1 -ResetEdit All
```

이 도구는 `Packages/` 밖에 있어 루트 원클릭 Start/Finish에 딸려 들어가지 않습니다. 프로젝트 미러 동기화는 검토 중 필요한 시점에만 수동으로 실행하는 단방향 작업이므로, 양방향 sync 어댑터(대화 세션/워크벤치 상태)와 묶지 않습니다.

## 코드 차이와 증거

- 코드 수정은 `Projects/<name>/edit/Claud`·`edit/Codex`(에이전트별)에서 합니다. `edit/<agent>` vs `baseline` diff가 그 에이전트의 제안이며, 빌드/테스트 산출물도 거기에 떨어집니다(전부 로컬).
- 채택 후보 patch·증거 artifacts는 해당 에이전트의 `Reviews/<id>/<agent>/artifacts/`에 남기되, 이는 사용자 관리 상태(상태 저장소)에 속합니다. 공개로 내보낼 때는 명시적으로 정제한 예시(`Examples/`)로만 공개합니다.

## 현재 안전 경계

- 대상 프로젝트 원본은 이 저장소에서 수정하지 않습니다.
- `Projects/<name>/baseline`은 읽기전용 기준이고, 코드 수정은 `edit/{Claud,Codex}`에서만 합니다.
- 현재 결론은 단일 파일(REVIEW.md/DECISION.md), 변경 이력은 상태 저장소의 git이 보존합니다.
- 실제 검토 인스턴스는 공개 저장소가 아니라 사용자 상태 저장소에 둡니다. `run-review.ps1`은 기본적으로 공개 저장소에 커밋하지 않으며, 상태 저장소/워크트리에서만 `-CommitToCurrentRepo`로 커밋을 명시합니다.
- 각 에이전트는 자기 폴더에만 씁니다(상대 폴더 읽기 전용). 최종 코드 적용·커밋·푸시는 사용자만, `DECISION.md` 기준.
- 로컬 인증정보, 에이전트 세션, IDE 상태, 빌드 산출물, 대상 프로젝트 코드는 이 저장소에 포함하지 않습니다.

## 참고

- 워크벤치 PowerShell 스크립트(`Start.ps1`, `Finish.ps1`, `sync.ps1`, `Reviews/run-review.ps1`, `Packages/*/*.ps1`)는 Windows PowerShell 5.1의 한글 파싱을 위해 **UTF-8 BOM**으로 저장합니다 — 벗기지 마세요. (no-BOM은 대상 엔진 소스/DevLog의 규칙이지 워크벤치 툴링 규칙이 아닙니다.)
- 2026-06-28 이전 검토 주제는 옛 번호파일 레이아웃(레거시)으로 그대로 보존합니다.

## 라이선스

MIT.
