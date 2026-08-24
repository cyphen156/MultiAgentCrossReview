# Workbench 상태 예시

이 디렉터리는 WorkbenchStateSync가 운반하는 상태의 모양을 보여주는 공개 예시입니다. 실제 사용자의 상태가 아니라 공개할 수 있도록 정리한 한 개의 교차 검토 사례를 담고 있습니다.

```text
Examples/WorkbenchState/
  UserSettings/preferences.example.md
  Projects/MultiAgentCrossReview/RULES.md
  Reviews/2026-07-03_MathUnitTypeDesign/
    README.md
    Claud/REVIEW.md
    Claud/artifacts/
    Codex/REVIEW.md
    DECISION.md
```

예시는 다음 관계를 보여줍니다.

- `UserSettings/preferences.md`: 개인의 안정적인 작업 선호
- `Projects/<name>/RULES.md`: 프로젝트별 규칙
- `Projects/<name>/MirrorTargets.json`: 프로젝트 미러 범위. 이 예시에는 미러 대상이 없어 포함하지 않았습니다.
- `Reviews/<review-id>/`: 실제 검토 주제, 두 에이전트의 판단, 증거와 사용자 결정

`Projects/projects.json`, `baseline/`과 `edit/`는 머신에서 다시 만드는 로컬 데이터라 WorkbenchStateSync가 운반하지 않습니다. 원문 대화 세션도 Workbench 상태가 아니며 AgentSessionSync가 별도로 다룹니다.

실제 상태는 WorkbenchStateVault와 현재 Workbench 사이에서 다음 명령으로 이동합니다.

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update review'
```
