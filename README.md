# MultiAgentCrossReview

MultiAgentCrossReview는 Claude와 Codex가 같은 문제를 각자 검토한 뒤, 서로의 판단을 교차 검증하도록 만든 공개 워크벤치입니다.

목표는 빠른 합의가 아닙니다. 처음부터 같은 답을 만들기보다 각자의 판단과 근거를 분리해 두고, 불일치가 생긴 지점을 다시 확인합니다. 사용자는 두 검토 결과와 증거를 바탕으로 최종 결정을 내립니다.

이 저장소에는 검토 절차, 공통 규칙, 실행 도구, 템플릿과 정제된 예시만 둡니다. 실제 프로젝트 경로, 개인 설정, 검토 기록, 원문 대화 세션은 공개 저장소에 포함하지 않습니다.

## 검토 흐름

```text
주제와 기준선 확정
    ↓
Claude · Codex 독립 검토
    ↓
서로의 판단 교차 검증
    ↓
각자 결론 수정 · 증거 재확인
    ↓
사용자 최종 결정
```

정식 검토에서는 두 에이전트가 상대의 초기 답변을 보기 전에 자기 판단을 먼저 기록합니다. 이후 단계에서 반박, 수정, 추가 증거와 사용자 Callback을 함께 반영합니다.

현재 결론은 에이전트별 `REVIEW.md`와 사용자 `DECISION.md`에 남기고, 변경 이력은 상태 저장소의 Git이 보존합니다. 자세한 기록 형식과 상태 전이는 [Reviews/README.md](Reviews/README.md)에 있습니다.

## 구성

한 Workbench는 하나의 WorkbenchStateVault와 연결되고, 그 안에는 여러 원본 프로젝트를 등록할 수 있습니다.

```text
Workbench : WorkbenchStateVault : Projects = 1 : 1 : Many
```

프로젝트마다 Workbench를 따로 두는 방식은 메모리와 작업 세션을 격리하기 위한 운용 선택입니다. 프레임워크 자체는 여러 프로젝트 등록을 지원합니다.

| 저장소 | 역할 |
|---|---|
| `MultiAgentCrossReview` | 공개 워크벤치. 검토 절차, 공통 규칙, 템플릿과 실행 도구를 제공합니다. |
| [`MultiAgentWorkbenchStateSync`](https://github.com/cyphen156/MultiAgentWorkbenchStateSync) | 워크벤치 상태 동기화 도구의 공개 MIT 원본입니다. |
| `MultiAgentWorkbenchStateVault` | 실제 설정, 프로젝트 규칙, 검토 기록을 보관하는 비공개 실사용 저장소입니다. |
| [`AgentSessionSync`](https://github.com/cyphen156/AgentSessionSync) | 등록된 에이전트 애플리케이션들의 대화 세션을 운반하는 공개 MIT 원본입니다. |
| `AgentSessionVault` | 여러 애플리케이션의 실제 세션 데이터를 보관하는 전역 비공개 저장소입니다. |

WorkbenchStateVault는 Workbench의 상태를 맡습니다. AgentSessionVault는 프로젝트나 Workbench 단위가 아니라 등록된 에이전트 애플리케이션 전체를 다루므로 위의 1:1:Many 관계와 별개입니다.

`MultiAgentWorkbenchStateSync`와 `AgentSessionSync`는 선택 기능입니다. 한 머신에서만 작업하거나 상태를 직접 관리한다면 연결하지 않아도 됩니다.

## 빠른 시작

### 1. 프로젝트 등록

`Projects/projects.example.json`을 `Projects/projects.json`으로 복사하고 원본 프로젝트의 로컬 경로를 적습니다. `projects.json`은 머신마다 경로가 달라 Git에 포함되지 않습니다.

```json
{
  "projects": [
    {
      "name": "ExampleProject",
      "sourceRepoRoot": "C:\\Path\\To\\ExampleProject"
    }
  ]
}
```

여러 프로젝트를 등록했다면 명령과 검토 주제에서 대상을 명시해야 합니다. 도구와 에이전트는 첫 번째 프로젝트를 임의로 선택하지 않습니다.

### 2. 프로젝트 미러 생성

ProjectSync는 원본 프로젝트에서 워크벤치 안으로만 복사하는 단방향 미러입니다.

```powershell
.\Packages\ProjectSync\Startup.ps1
.\Packages\ProjectSync\Sync.ps1 -Project ExampleProject
```

`baseline/`은 검토 기준이 되는 읽기 전용 사본이고, `edit/Claud`와 `edit/Codex`는 각 에이전트의 수정 제안 공간입니다. 어떤 파일을 복사할지는 `Projects/<name>/MirrorTargets.json`으로 정하며, 형식은 [Common/MIRROR_SPEC.md](Common/MIRROR_SPEC.md)에 있습니다.

### 3. 검토 시작

```powershell
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-29_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Status
.\Reviews\run-review.ps1 -Topic 2026-06-29_Example -Steps 8
```

등록 프로젝트가 여러 개라면 `-Project <name>`을 함께 지정합니다. 워크벤치 자체를 검토할 때는 `-Project none`을 사용할 수 있습니다.

### 4. 선택: 다른 머신과 상태 공유

실사용 WorkbenchStateVault를 등록한 뒤 `Start`로 가져오고 `Finish`로 돌려보냅니다.

```powershell
.\Packages\WorkbenchStateSync\Register.ps1 -ToolRoot C:\Path\To\MultiAgentWorkbenchStateVault
.\Packages\WorkbenchStateSync\Start.ps1
.\Packages\WorkbenchStateSync\Finish.ps1
```

원문 대화 세션도 공유하려면 별도의 AgentSessionVault를 등록합니다.

```powershell
.\Packages\AgentSessionSync\Register.ps1 -ToolRoot C:\Path\To\AgentSessionVault
.\Packages\AgentSessionSync\Start.ps1
.\Packages\AgentSessionSync\Finish.ps1
```

루트의 `Start.ps1`과 `Finish.ps1`은 설정된 외부 동기화 어댑터를 한 번에 실행합니다. ProjectSync는 단방향 `Sync` 도구이므로 이 버튼에 포함되지 않습니다.

```powershell
.\Start.ps1
.\Finish.ps1
.\Start.ps1 -Include WorkbenchStateSync
.\Finish.ps1 -Include AgentSessionSync
```

Windows 바로가기는 로컬에서 다시 생성합니다.

```powershell
.\Launchers\Create-Shortcuts.ps1
```

`Launchers/Shortcuts/`의 `.lnk` 파일은 저장소에서 추적하지만 머신 절대경로를 포함하므로, 새로 clone한 뒤에는 위 명령으로 현재 경로에 맞춰야 합니다.

## 디렉터리 안내

```text
Common/                 공통 규칙, 라우팅, 프로젝트 미러 스펙
Projects/               로컬 프로젝트 등록부와 baseline/edit 사본
Reviews/                검토 절차, 템플릿, 오케스트레이터
Packages/ProjectSync/   내장 프로젝트 미러 도구
Packages/*Sync/         외부 동기화 도구를 부르는 어댑터
UserSettings/           공개 저장소에 넣지 않는 개인 설정
Claud/ · Codex/         검토자 역할 안내
Examples/               공개 가능한 정제 예시
```

공개 저장소에 포함되는 것은 프레임워크 파일뿐입니다. 다음 항목은 로컬 또는 사용자가 지정한 비공개 Vault에 둡니다.

- `Projects/projects.json`과 원본 프로젝트 절대경로
- `Projects/<name>/RULES.md`, `MirrorTargets.json`, `baseline/`, `edit/`
- 실제 `Reviews/<review-id>/` 기록과 증거
- `UserSettings/`의 개인 설정과 로컬 도구 등록부
- 원문 대화 세션, 인증정보, 빌드 산출물

원본 프로젝트는 기본적으로 읽기 전용입니다. 워크벤치 수정 권한이나 검토 요청이 원본 프로젝트 수정 권한을 뜻하지 않습니다. 원본에 실제 변경을 적용하려면 사용자가 대상과 작업을 명시적으로 위임해야 합니다.

## 문서 언어와 실사용 권장

이 공개 저장소의 문서는 관리자가 직접 읽고 운영하기 편하도록 한국어를 기본으로 씁니다. 공개 프로젝트라는 이유만으로 모든 설명을 영어로 유지할 필요는 없습니다.

다만 이 템플릿으로 실제 Workbench를 구성할 때, 에이전트에게 반복해서 주입되는 규칙 파일은 간결한 영어로 작성하는 편을 권장합니다.

- `AGENTS.md`, `CLAUDE.md`
- `Common/SHARED_RULES.md`, `Common/ROUTING.md`
- `Claud/ROLE.md`, `Codex/ROLE.md`
- `Projects/<name>/RULES.md`
- 에이전트가 항상 읽는 `UserSettings/preferences.md`

코딩 에이전트와 개발 도구는 영어 명령, 경로, 식별자를 중심으로 동작하고, 많은 모델·토크나이저에서 간결한 영어 지침이 한국어보다 적은 토큰을 쓰는 경우가 많습니다. 다만 모델과 문장에 따라 차이가 있으므로 영어가 항상 더 정확하거나 더 짧다고 보장할 수는 없습니다.

실사용 규칙은 한 언어로 짧게 유지하는 것이 중요합니다. 같은 규칙을 한국어와 영어로 중복 작성하면 두 사본이 어긋나거나 에이전트가 서로 다른 문장을 별도 규칙으로 해석할 수 있습니다. 사용자를 위한 설명은 한국어로 두고, 반복 주입되는 에이전트 규칙만 필요에 따라 영어로 작성합니다. 명령어, 파일명, 설정 키와 코드 식별자는 번역하지 않습니다.

## 문서 안내

- [Common/ROUTING.md](Common/ROUTING.md): 작업에 따라 어떤 규칙을 읽을지 정합니다.
- [Common/SHARED_RULES.md](Common/SHARED_RULES.md): 모든 작업에 적용되는 안전 경계와 공통 원칙입니다.
- [Common/MIRROR_SPEC.md](Common/MIRROR_SPEC.md): `MirrorTargets.json` 형식과 ProjectSync 동작을 설명합니다.
- [Reviews/README.md](Reviews/README.md): 정식 교차 검토의 기록 형식과 상태 흐름입니다.
- [Packages/ProjectSync/README.md](Packages/ProjectSync/README.md): 프로젝트 미러 사용법입니다.
- [Packages/WorkbenchStateSync/README.md](Packages/WorkbenchStateSync/README.md): 워크벤치 상태 Vault 연결법입니다.
- [Packages/AgentSessionSync/README.md](Packages/AgentSessionSync/README.md): 전역 세션 Vault 연결법입니다.
- [UserSettings/README.md](UserSettings/README.md): 개인 설정과 로컬 등록부의 경계입니다.

## 지원 범위

기본 오케스트레이터가 공식 지원하는 검토자 조합은 Claude와 Codex입니다. MIT 라이선스에 따라 다른 에이전트의 역할 파일, 실행부, 템플릿과 단계를 추가할 수 있지만, 해당 확장은 기본 지원 범위에 포함되지 않습니다.

## 라이선스

MIT
