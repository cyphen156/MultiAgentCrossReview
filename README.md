# MultiAgentCrossReview

MultiAgentCrossReview는 여러 AI 에이전트가 같은 주제를 먼저 독립적으로 판단하고, 이후 서로의 주장과 근거를 교차 검증하도록 만드는 공개 검토 워크벤치입니다.

목표는 에이전트 사이의 합의를 빠르게 만드는 것이 아닙니다. 독립 판단 사이의 불일치를 보존하고, 반박·수정·증거 확인·사용자 Callback을 거쳐 설계 결함과 불확실성을 드러내는 것이 목적입니다.

## 저장소 역할

| 저장소 | 역할 | 포함하는 것 |
|---|---|---|
| `MultiAgentCrossReview` | 공개 MIT 워크벤치 | 범용 규칙, 프로젝트 템플릿, RuleSync 엔진, 독립 판단(REVIEW.md), 교차검증, 증거, Callback, 최종 결정(DECISION.md) |
| [`MultiAgentPrivateRulesSync`](https://github.com/cyphen156/MultiAgentPrivateRulesSync) | 공개 MIT 예시 vault | private rules vault를 어떻게 구성하는지 보여주는 샘플 `UserSettings/`·`Projects/<name>/RULES.md` |
| 개인 `MultiAgentRulesVault` | 비공개 실제 룰 vault | 사용자의 실제 `UserSettings/**/*.md`, 실제 `Projects/<name>/RULES.md` |
| `AgentSessionSync` / `AgentSessionVault` | 비공개 세션 운반 계층 | Codex·Claude 원본 세션 JSONL, baton, 시작·종료 스크립트 |

이 저장소의 `Reviews/`가 공개 검토 기록의 기준입니다. 원문 대화(JSONL)는 시스템 지침·도구 출력·절대경로까지 포함한 실행 로그라서 이 저장소에 두지 않고 `AgentSessionSync`가 따로 운반합니다.

룰 동기화와 세션 동기화는 분리합니다. 룰은 `Packages/RuleSync/`가 private rules vault와 동기화하고, 대화 세션은 `AgentSessionSync`가 별도 vault와 동기화합니다.

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
Common/SHARED_RULES.md      범용 워크벤치 규칙 (SSOT)
Common/PROJECT_RULES.template.md  프로젝트별 규칙 템플릿 (공개)
UserSettings/               개인 설정 공간 (README만 공개, 하위 파일은 로컬 전용·gitignore)
Claud/ROLE.md               Claude 역할
Codex/ROLE.md               Codex 역할
Packages/RuleSync/          private markdown rule sync engine (public package)

Projects/                   대상 프로젝트 코드 공간 (Projects/<name>/** 는 로컬 전용·gitignore)
  projects.example.json     공개 예시 등록부
  projects.json             로컬 등록부(gitignore) — sync 대상 프로젝트 목록
  <name>/
    RULES.md                프로젝트별 규칙 (로컬 전용·gitignore)
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

`Projects/<name>/` 하위(미러·편집본·빌드 산출물)는 전부 로컬 전용이라 `.gitignore`로 제외합니다. 실제 등록부 `Projects/projects.json`도 로컬 전용이며, 공개 저장소에는 `Projects/projects.example.json`만 둡니다. 대상 프로젝트 이름, 절대경로, 코드는 공개 저장소에 커밋하지 않습니다.

`Packages/RuleSync/`는 공개 패키지이지만 실제 vault 경로는 공개하지 않습니다. 로컬 설정 파일(`Packages/RuleSync/rulesync.config.psd1`, `RuleSync.local.psd1`)은 gitignore 대상입니다.

## 규칙 계층

규칙은 성격에 따라 세 층으로 나눕니다. 공개 레포에는 **범용 규칙과 템플릿만** 들어가고, 특정 프로젝트·개인에 묶이는 규칙은 로컬 전용(gitignore)입니다.

| 층 | 위치 | 공개 | 내용 |
|---|---|---|---|
| 범용 워크벤치 | `Common/SHARED_RULES.md`, `Reviews/README.md` | 공개 | 독립판단→교차검증 절차, 범용 커밋 본문 구조, Reviews 운영 |
| 프로젝트별 | `Projects/<name>/RULES.md` (템플릿 `Common/PROJECT_RULES.template.md`) | 로컬 | 코드 스타일·인코딩·줄바꿈·아키텍처·DevLog 경로·커밋 제목 관례 |
| 개인 설정 | `UserSettings/` (안내 `UserSettings/README.md`) | 로컬 | 어조·검토 태도·사적 워크플로 등 사용자 설정 |

`run-review.ps1`은 활성 프로젝트(`projects.json` 첫 항목 또는 `-Project`)의 `RULES.md`를 범용 규칙과 함께 헤드리스 프롬프트에 주입합니다. `RULES.md`가 없으면 경고 후 범용 규칙만으로 진행합니다. 즉, 헤드리스 리뷰 오케스트레이터는 누락된 프로젝트 룰에 대해 **fail-open**입니다.

커밋 메시지나 DevLog처럼 프로젝트별 형식이 있는 산출물은 활성 프로젝트의 `Projects/<name>/RULES.md`를 먼저 읽은 뒤 작성합니다. 해당 파일이 없으면 기억으로 작성하지 않고, 누락된 프로젝트 룰을 먼저 보고합니다. 즉, 대화형 커밋/DevLog 초안 작성은 **fail-closed**입니다.

프로젝트별 커밋 본문에서 `검증`, `다음 작업`은 자주 쓰는 선택 섹션일 뿐 닫힌 목록이 아닙니다. 선택 섹션은 커밋 성격이나 사용자 명시 지시에 따라 제거, 추가, 이름 변경될 수 있습니다.

프로젝트별 DevLog는 작성 시각만으로 범위를 정하지 않습니다. 각 프로젝트 룰이 정한 방식으로 이전 DevLog 이후의 대상 커밋 범위를 산정하며, CyphenEngine은 이전 DevLog auto-generated commit 이후부터 마지막 대상 커밋까지의 포맷 커밋을 검토하고 DevLog auto-generated commit 자체는 요약 범위에서 제외합니다.

## RuleSync

`UserSettings/**/*.md`와 `Projects/<name>/RULES.md`는 공개 저장소에 커밋하지 않는 로컬 룰입니다. 여러 머신에서 이 파일을 이어 쓰려면 `Packages/RuleSync/`를 사용해 별도의 private rules vault와 동기화합니다.

원칙:

- private rules vault = private markdown rule SSOT.
- 이 워크트리의 `UserSettings/`와 `Projects/<name>/RULES.md` = 에이전트가 실제로 읽는 materialized copy.
- Claude/Codex memory = 캐시 또는 참고 맥락일 뿐 SSOT가 아닙니다.
- `Projects/<name>/baseline/**`와 `Projects/<name>/edit/**`는 RuleSync 대상이 아닙니다.
- `README.md` 파일은 RuleSync 대상이 아닙니다. 공개 안내 문서는 공개 repo에 남기고, private vault에는 실제 룰 데이터만 둡니다.

설정:

```powershell
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
```

`rulesync.config.psd1`은 gitignore 대상입니다. 여기에 사용자의 private vault 경로를 지정합니다.

예:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Pull   # private vault -> 현재 워크트리
.\Packages\RuleSync\rulesync.ps1 -Direction Push   # 현재 워크트리 -> private vault
```

RuleSync는 다른 내용의 대상 파일을 조용히 덮어쓰지 않습니다. 충돌 시 대상 파일을 `.bak`으로 백업하고 경고한 뒤 건너뛰며, `-Force`가 있을 때만 덮어씁니다.

공개 예시 vault 구조는 별도 MIT 공개 repo [MultiAgentPrivateRulesSync](https://github.com/cyphen156/MultiAgentPrivateRulesSync)로 제공합니다. 실제 개인 룰 저장소는 이 예시를 참고해 별도 private repository로 만듭니다.

## 빠른 시작

```powershell
# 1) 대상 프로젝트 등록 (Projects/projects.example.json -> Projects/projects.json 로 복사 후 로컬 경로 수정)
#    { "projects": [ { "name": "ExampleProject", "sourceRepoRoot": "C:\\Path\\To\\ExampleProject", "engineSubdir": "ExampleProject" } ] }

# 2) 등록 프로젝트 동기화 — baseline 채우고 edit/Claud·edit/Codex 시드
.\sync.ps1                        # 매니페스트 전체
.\sync.ps1 -Project ExampleProject # 특정 프로젝트
.\sync.ps1 -ResetEdit All         # 편집 사본 강제 재시드

# 3) private rule vault 설정 및 로컬 룰 materialize
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
# rulesync.config.psd1의 VaultRoot를 private rules vault clone 경로로 수정
.\Packages\RuleSync\rulesync.ps1 -Direction Pull

# 4) 새 검토 주제 생성 + 진행
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-29_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Status   # 현재 상태
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Steps 8  # 끝까지
```

자세한 기록 규칙은 `Reviews/README.md`, 범용 판단 규칙은 `Common/SHARED_RULES.md`, 프로젝트별 규칙은 `Projects/<name>/RULES.md`를 참고합니다.

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
