# UserSettings

이 디렉터리는 공개 저장소에 넣지 않을 개인 설정과 로컬 등록 정보를 두는 곳입니다. 이 README와 공개 예시만 Git이 추적하며, 실제 설정 파일은 제외됩니다.

## 개인 설정

권장 파일은 다음과 같습니다.

```text
UserSettings/preferences.md       말투, 검토 태도, 안정적인 개인 작업 방식
UserSettings/session.md           현재 작업의 로컬 인계 메모
UserSettings/machines/<name>.md   머신별 참고 사항
```

`preferences.md`가 있으면 모든 작업에서 읽습니다. 다른 파일은 현재 작업에 필요할 때만 읽습니다. 개인 설정은 플랫폼 안전, 원본 보호와 권한 경계를 약화할 수 없습니다.

공개 Workbench 규칙은 `Common/SHARED_RULES.md`에, 프로젝트별 코드와 문서 규칙은 `Projects/<name>/RULES.md`에 둡니다.

## 동기화 도구 등록부

`sync-tools.json`은 이 Workbench가 어떤 로컬 Vault를 호출할지 기록합니다.

```text
UserSettings/sync-tools.example.json   공개 예시
UserSettings/sync-tools.json           실제 로컬 등록부, Git 제외
```

등록은 각 패키지의 `Register.ps1`로 합니다.

```powershell
.\Packages\WorkbenchStateSync\Register.ps1 -ToolRoot C:\Path\To\MultiAgentWorkbenchStateVault
.\Packages\AgentSessionSync\Register.ps1 -ToolRoot C:\Path\To\AgentSessionVault
```

`toolRoot`는 절대경로나 Workbench 루트 기준 상대경로를 사용할 수 있습니다. 머신 절대경로를 담을 수 있으므로 실제 등록부를 공개 저장소나 WorkbenchStateVault로 동기화하지 않습니다.

어댑터는 등록부를 먼저 읽고, 구형 패키지별 psd1 설정, 표준 이름의 로컬 형제 private Vault 순서로 fallback합니다. 공개 Sync 저장소는 private 상태 저장소로 자동 선택하지 않습니다. 자동 탐색은 현재 실행에만 적용되며 `sync-tools.json`을 만들거나 수정하지 않습니다.

WorkbenchStateVault가 개인 설정, 프로젝트 규칙과 실제 리뷰 기록의 기준 저장소입니다. `Start.ps1`로 현재 Workbench에 가져오고 `Finish.ps1`로 돌려보냅니다.
