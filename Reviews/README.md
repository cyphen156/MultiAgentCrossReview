# 교차 검토 기록

`Reviews/`는 Claude와 Codex가 같은 주제를 독립적으로 검토하고, 서로의 근거를 다시 확인한 뒤 사용자가 최종 결정을 남기는 형식입니다.

## 공개 저장소와 실제 기록

공개 MultiAgentCrossReview 저장소에는 다음 프레임워크 파일만 둡니다.

```text
Reviews/README.md
Reviews/_TEMPLATE/
Reviews/run-review.ps1
```

실제 `Reviews/<review-id>/`는 사용자가 관리하는 WorkbenchStateVault 또는 상태 작업 트리에 둡니다. 개인 프로젝트의 근거, Callback과 검토 기록을 공개 템플릿의 Git 이력에 커밋하지 않습니다.

## 검토 흐름

```text
주제와 baseline 마커 확정
    ↓
Claude · Codex 독립 판단
    ↓
양방향 교차 검증
    ↓
각자 결론 수정
    ↓
증거 재확인
    ↓
사용자 최종 결정
```

독립 판단 단계에서는 상대의 초기 답변을 읽지 않습니다. 두 답변이 모두 끝난 뒤에는 불일치와 반박을 숨기지 않고 함께 검토합니다. 사용자는 어느 단계에서든 `README.md`에 Callback을 추가할 수 있으며, 에이전트는 이를 검토 조건과 추가 근거로 평가합니다.

검토를 시작하기 전에 baseline 마커와 필요한 파일이 의도한 원본 스냅숏인지 확인합니다. baseline은 ProjectSync 시점의 로컬 파일을 미러 스펙 범위 안에서 복사하므로 미커밋 내용을 포함할 수 있습니다. 검토 도중 원본이 바뀌어도 baseline을 자동 갱신하지 않습니다.

## 디렉터리 구조

```text
Reviews/<review-id>/
  README.md
  Claud/
    REVIEW.md
    artifacts/
  Codex/
    REVIEW.md
    artifacts/
  DECISION.md
```

- `README.md`: 주제, 프로젝트, baseline, 범위, 상태와 사용자 Callback
- `Claud/REVIEW.md`, `Codex/REVIEW.md`: 각 검토자의 현재 판단
- `artifacts/`: 채택 후보 패치나 검토에 필요한 증거
- `DECISION.md`: 사용자의 최종 판정

각 에이전트는 자기 `REVIEW.md`만 씁니다. 상대 폴더는 읽기 전용입니다. 현재 결론은 단일 파일에 유지하고, 단계별 이력은 상태 저장소의 Git 커밋으로 남깁니다.

## 메타데이터

`REVIEW.md`와 `DECISION.md` 상단에는 다음 정보를 기록합니다.

```text
Review-ID: 2026-06-28_Example
Author: Claude
Baseline: <snapshot marker>
Project-Rules: <source>
Role-Source: <source>
Session-Id:
Status: Initial
```

- `Author`: `Claude`, `Codex`, `User`
- `Baseline`: ProjectSync가 기록한 baseline 표식
- `Project-Rules`: 사용한 프로젝트 규칙 파일 또는 `shared-only`
- `Role-Source`: 사용한 역할 파일 또는 내장 fallback
- `Session-Id`: 선택 항목. 관련 세션을 식별하는 라벨만 기록하며 경로나 원문은 적지 않습니다.
- `Status`: 현재 검토 단계

`Project-Rules`와 `Role-Source`는 오케스트레이터가 기록합니다. 선택 파일이 없더라도 검토는 계속하고 어떤 fallback을 사용했는지 남깁니다.

## 상태 전이

```text
REVIEW.md   Initial → Cross-reviewed → Revised → Evidence-checked
DECISION.md                                             → Decided
```

현재 파일을 갱신하고 각 단계를 Git 커밋으로 기록합니다. 번호를 붙인 대체 파일이나 `Supersedes` 체인을 만들지 않습니다. 2026-06-28 이전 형식의 기존 토픽은 레거시 기록으로 그대로 두며, 요청 없이 변환하지 않습니다.

## 코드 제안

코드 변경 제안은 `Projects/<name>/edit/Claud`와 `edit/Codex`에서 만듭니다. 각 edit 사본과 baseline의 diff가 해당 에이전트의 제안입니다.

검토 기록에 보존할 가치가 있는 작은 패치나 증거만 `artifacts/`에 둡니다. 실제 원본 프로젝트 적용, 커밋과 푸시는 사용자가 최종 결정에 따라 별도로 수행하거나 명시적으로 위임합니다.

## 실행

```powershell
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-28_Example -Recurse
.\Reviews\run-review.ps1 -Topic 2026-06-28_Example
.\Reviews\run-review.ps1 -Topic 2026-06-28_Example -Status
.\Reviews\run-review.ps1 -Topic 2026-06-28_Example -Steps 8
```

등록 프로젝트가 여러 개라면 `-Project <name>`을 지정합니다. 프로젝트를 사용하지 않는 Workbench 자체 검토는 `-Project none`으로 시작할 수 있습니다.
