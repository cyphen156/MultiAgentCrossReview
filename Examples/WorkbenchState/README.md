# 워크벤치 상태 예시

이 디렉터리는 WorkbenchStateSync가 옮기는 상태를 보여주는 공개 예시입니다.

실제 검토 인스턴스는 공개 프레임워크 저장소가 추적하면 안 되므로, `Reviews/`가 아니라 `Examples/` 아래에 둡니다.

## 무엇을 보여주는가

지어낸 예시가 아니라 **실제로 진행된 교차 검토 세션**을 그대로 담았습니다. 주제는 `2026-07-03_MathUnitTypeDesign`(Math 클래스 형태·모듈 경계·기본 단위계·좌표 규약·기초 자료형 설계)이며, 다음을 함께 보여줍니다.

- Claude와 Codex의 독립 판단(`Claud/REVIEW.md`, `Codex/REVIEW.md`)
- 양방향 교차 검증과 각자의 수정
- 증거 확인과 baseline 대조
- 채택 후보 산출물(`Claud/artifacts/*.h`)
- 사용자 최종 결정(`DECISION.md`)

동시에 상태의 구조도 보여줍니다.

- 공개 `MultiAgentCrossReview`는 프레임워크 파일만 보관하고,
- 실제 `Reviews/<review-id>/` 기록은 사용자 관리 상태 저장소를 통해 이동하며,
- `WorkbenchStateSync`가 그 상태를 옮기는 버튼 같은 전송 도구이고,
- 원문 세션 JSONL은 검토 상태와 분리되어 `AgentSessionSync`가 따로 운반합니다.

프로젝트 폴더에서 운반되는 것은 **그 프로젝트의 성질을 적은 파일 둘뿐**입니다 — 규칙(`RULES.md`)과 미러 대상(`MirrorTargets.json`). 이 예시의 `MultiAgentCrossReview`는 원본을 미러하지 않는 프로젝트라 스펙 파일이 없습니다. 형식은 `Common/MIRROR_SPEC.md`에 있습니다.

`baseline/`·`edit/` 는 로컬 사본이라 운반 대상이 아니고, `Projects/projects.json`도 머신마다 다른 절대경로를 담아 운반하지 않습니다. 그래서 예시에도 없습니다.

## 공개 예시 경로

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

## 대응하는 실제 상태 경로

```text
UserSettings/preferences.md
Projects/<name>/RULES.md
Projects/<name>/MirrorTargets.json
Reviews/<review-id>/README.md
Reviews/<review-id>/Claud/REVIEW.md
Reviews/<review-id>/Codex/REVIEW.md
Reviews/<review-id>/DECISION.md
```

실제 버전은 설정된 상태 저장소/워크트리에 있으며 다음으로 동기화합니다.

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update review'
```
