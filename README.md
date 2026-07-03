# MultiAgentCrossReview

MultiAgentCrossReview는 여러 AI 에이전트가 같은 주제를 먼저 독립적으로 판단하고, 이후 서로의 주장과 근거를 교차 검증하도록 만드는 공개 검토 워크벤치입니다.

목표는 에이전트 사이의 합의를 빠르게 만드는 것이 아닙니다.  
독립 판단 사이의 불일치를 보존하고, 반박·수정·증거 확인·사용자 Callback을 거쳐 설계 결함과 불확실성을 드러내는 것이 목적입니다.

이 저장소는 **실제 검토 기록의 공개 아카이브가 아닙니다.** 프로세스, 템플릿, 도구, 정제된 예시만 보관합니다.  
실제 검토 기록과 사용자별 설정은 사용자가 직접 지정한 **상태 저장소(state repository)**에 둡니다.

## 저장소 역할

| 저장소 | 공개 범위 | 역할 |
|---|---|---|
| `MultiAgentCrossReview` | 공개 MIT | 검토 프로세스, 템플릿, 오케스트레이션 스크립트, 도구 사본, 정제된 예시 |
| [`MultiAgentWorkbenchStateSync`](https://github.com/cyphen156/MultiAgentWorkbenchStateSync) | 공개 MIT | 사용자 관리 워크벤치 상태를 동기화하는 독립 도구 |
| 사용자 상태 저장소 | 사용자 지정 | 실제 `UserSettings/`, `Projects/<name>/RULES.md`, `Reviews/<review-id>/` 기록. 보통 비공개 |
| [`AgentSessionSync`](https://github.com/cyphen156/AgentSessionSync) | 공개 MIT | Codex·Claude 원본 세션(JSONL)을 별도로 운반하는 전용 도구 |

원문 대화(JSONL)는 시스템 지침·도구 출력·절대경로까지 포함한 실행 로그라서 이 저장소에 두지 않고 `AgentSessionSync`가 따로 운반합니다.  
`WorkbenchStateSync`와 `AgentSessionSync`는 둘 다 선택 기능입니다. 한 대의 머신에서만 작업한다면 쓰지 않아도 됩니다. 여러 머신에서 같은 작업 상태를 이어갈 때만, 사용자가 직접 만든 저장소를 대상으로 경로를 설정해 사용합니다.

## 공개 / 비공개 경계

이 저장소에 두는 공개 콘텐츠:

- `Common/**`
- `Reviews/README.md`
- `Reviews/_TEMPLATE/**`
- `Reviews/run-review.ps1`
- `Packages/WorkbenchStateSync/**`
- `Examples/**`

여기에 커밋하면 안 되는 사용자 관리 상태:

- 실제 `Reviews/<review-id>/` 인스턴스
- 사용자 Callback 및 사용자 발화에서 파생된 검토 맥락
- 실제 `Claud/REVIEW.md`, `Codex/REVIEW.md`, `DECISION.md` 기록
- 실제 검토 artifacts와 채택 후보 patch
- 로컬 `UserSettings/**/*.md`
- 로컬 `Projects/<name>/RULES.md`
- 원문 세션 JSONL, 토큰, 자격증명, 머신 절대경로, 로그

실제 상태 저장소의 이름·URL·절대경로는 공개 README에 고정하지 않습니다.

## 예시

`Examples/WorkbenchState/`는 추적되는 공개 예시입니다. 지어낸 예시가 아니라 **실제로 진행된 교차 검토 세션**(`2026-07-03_MathUnitTypeDesign` — Math·단위·좌표 자료형 설계)을 그대로 담아, WorkbenchStateSync가 옮기는 상태의 형태와 실제 검토 내용을 함께 보여줍니다.

```text
Examples/WorkbenchState/
  UserSettings/preferences.example.md
  Projects/MultiAgentCrossReview/RULES.md
  Reviews/2026-07-03_MathUnitTypeDesign/
    README.md
    Claud/REVIEW.md
    Claud/artifacts/*.h
    Codex/REVIEW.md
    DECISION.md
```

실제 상태 저장소에서는 같은 형태가 접두 경로 없이 다음 위치에 놓입니다.

```text
UserSettings/preferences.md
Projects/<name>/RULES.md
Reviews/<review-id>/README.md
Reviews/<review-id>/Claud/REVIEW.md
Reviews/<review-id>/Codex/REVIEW.md
Reviews/<review-id>/DECISION.md
```

공개 `Reviews/<review-id>/` 아래에 실제 검토 인스턴스를 만들지 마세요. `.gitignore`가 무시하며, 상태 저장소를 통해 동기화되어야 합니다.

## 일상 흐름

사용자 관리 상태를 워크벤치로 가져오기(pull):

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
```

상태가 복원된 워크트리에서 새 실제 검토 생성:

```powershell
Copy-Item .\Reviews\_TEMPLATE .\Reviews\2026-07-04_MyTopic -Recurse
```

검토 상태 확인·진행:

```powershell
.\Reviews\run-review.ps1 -Topic 2026-07-04_MyTopic -Status
.\Reviews\run-review.ps1 -Topic 2026-07-04_MyTopic -Steps 1
```

`run-review.ps1`은 기본적으로 공개 저장소에 커밋하지 않습니다. 상태 저장소/워크트리에서만 `-CommitToCurrentRepo`로 커밋을 명시할 수 있습니다.

사용자 관리 상태를 지정된 상태 저장소로 되돌려 보내기(push):

```powershell
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update review'
```

## WorkbenchStateSync

`Packages/WorkbenchStateSync/`는 동기화 도구의 저장소 내 사본입니다. 다음을 동기화합니다.

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
Reviews/<review-id>/**
```

공개 프레임워크 파일과 로컬 작업 사본은 제외합니다.

```text
UserSettings/README.md
Reviews/README.md
Reviews/_TEMPLATE/**
Reviews/run-review.ps1
Projects/<name>/baseline/**
Projects/<name>/edit/**
*.jsonl, *.db, *.sqlite, *.key, *.pem, *.env, *.user, *.log
```

이 도구는 매니페스트 기반의 기계적 동기화입니다. 대상 원격이 비공개인지 공개인지는 도구가 판단하지 않으며, 무엇을 올릴지는 위 포함/제외 목록이, 어디로 올릴지는 사용자 설정이 정합니다. Push 시 토큰류 유출을 막기 위한 시크릿 스캔만 안전장치로 남아 있습니다.

로컬 대상 설정:

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

그 다음 `workbenchstatesync.config.psd1`을 편집합니다.

```powershell
@{
    VaultRoot = 'D:\State\MultiAgentWorkbenchState'
    WorktreeRoot = ''
}
```

`workbenchstatesync.config.psd1`과 `WorkbenchStateSync.local.psd1`은 로컬 전용이며 git이 무시합니다.

## 검토 모델

각 검토 주제는 역할마다 가변 파일 하나를 씁니다.

```text
Reviews/<review-id>/
  README.md
  Claud/REVIEW.md
  Codex/REVIEW.md
  DECISION.md
```

현재 진실은 작업트리의 파일이고, 변경 이력은 상태 저장소의 git 이력입니다.

Claude와 Codex의 초기 판단은 서로 독립적이어야 합니다. 둘 다 존재한 뒤에야 각 에이전트가 상대 결과를 교차 검증하며 불일치·근거 부족·경계 문제를 기록합니다. 사용자 Callback은 평가 대상 입력이지 자동 정답이 아닙니다.

## 프로젝트 미러

`Projects/<name>/baseline/`은 검토에 쓰는 읽기 전용 미러입니다. 에이전트별 편집 사본은 다음 위치에 둡니다.

```text
Projects/<name>/edit/Claud/
Projects/<name>/edit/Codex/
```

이 폴더들은 로컬 작업 자료이며 WorkbenchStateSync 동기화 대상이 아닙니다. 등록된 프로젝트의 baseline·edit 재동기화는 `sync.ps1`이 담당합니다.

```powershell
.\sync.ps1                         # 매니페스트 전체
.\sync.ps1 -Project ExampleProject # 특정 프로젝트
.\sync.ps1 -ResetEdit All          # 편집 사본 강제 재시드
```

## 규칙

규칙 로딩 순서:

1. `AGENTS.md`
2. `Common/ROUTING.md`
3. `Common/SHARED_RULES.md`
4. `Reviews/README.md`
5. `Projects/<active>/RULES.md`
6. 로컬 `UserSettings/` 파일(있을 때)

프로젝트별 커밋 메시지나 DevLog 초안을 작성하기 전에 `Projects/<active>/RULES.md`를 먼저 읽습니다.

## 라이선스

MIT.
