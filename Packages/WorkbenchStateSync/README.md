# WorkbenchStateSync 어댑터

이 패키지는 MultiAgentCrossReview의 `Start`·`Finish` 버튼을 외부 MultiAgentWorkbenchStateSync 도구에 연결합니다. 실제 복사, 충돌 처리와 시크릿 검사는 외부 도구가 담당하고, 이 패키지는 선택한 ToolRoot의 런처를 호출합니다.

Workbench와 WorkbenchStateVault의 관계는 1:1입니다. Vault에는 이 Workbench의 개인 설정, 프로젝트 규칙, 미러 스펙과 실제 검토 기록을 보관합니다.

## 등록

```powershell
.\Packages\WorkbenchStateSync\Register.ps1 -ToolRoot C:\Path\To\MultiAgentWorkbenchStateVault
```

등록 정보는 Git에서 제외되는 `UserSettings/sync-tools.json`에 저장합니다. 상대경로를 적으면 Workbench 루트 기준으로 해석합니다.

도구 경로는 다음 순서로 찾습니다.

1. `Start.ps1` 또는 `Finish.ps1`에 직접 전달한 `-ToolRoot`
2. `UserSettings/sync-tools.json`
3. 구형 `Packages/WorkbenchStateSync/workbenchstatesync.config.psd1`
4. 로컬 형제 폴더 `../MultiAgentWorkbenchStateVault`

형제 폴더 탐색은 현재 실행에서만 경로를 찾아 쓰며 등록부를 수정하지 않습니다. 공개 `MultiAgentWorkbenchStateSync` 저장소는 private 상태 Vault가 아니므로 자동 선택하지 않습니다. `<Project>WorkbenchStateVault`처럼 다른 이름을 쓰면 반드시 `Register.ps1`로 등록합니다.

## 사용

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
.\Packages\WorkbenchStateSync\Finish.ps1
```

어댑터는 선택한 ToolRoot를 `VaultRoot`로, 현재 저장소를 `WorktreeRoot`로 외부 런처에 전달합니다. 루트 `Start.ps1`과 `Finish.ps1`도 설정된 이 패키지를 실행합니다. 등록 자체가 없으면 `SKIP`하지만, 등록된 Vault의 런처가 없거나 ToolRoot 밖을 가리키면 잘못된 설치이므로 실패합니다.

프로젝트 미러 갱신은 상태 동기화에 포함되지 않습니다. 필요할 때 `Packages/ProjectSync/Sync.ps1`을 따로 실행합니다.
