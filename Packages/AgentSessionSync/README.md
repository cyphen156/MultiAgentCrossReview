# AgentSessionSync 어댑터

이 패키지는 MultiAgentCrossReview의 `Start`·`Finish` 버튼을 외부 AgentSessionSync 도구에 연결합니다. 세션 복사, 보존과 충돌 처리는 구현하지 않고, 선택한 ToolRoot의 `Launchers/Start.ps1`과 `Launchers/Finish.ps1`을 호출합니다.

AgentSessionSync는 프로젝트별 Workbench 상태가 아니라 등록된 에이전트 애플리케이션들의 대화 세션을 다룹니다. 하나의 AgentSessionVault가 여러 애플리케이션의 실제 세션 데이터를 보관하며, 세부 보존 정책과 애플리케이션 경로는 해당 Vault의 문서와 설정이 소유합니다.

## 등록

```powershell
.\Packages\AgentSessionSync\Register.ps1 -ToolRoot C:\Path\To\AgentSessionVault
```

등록 정보는 Git에서 제외되는 `UserSettings/sync-tools.json`에 저장합니다. 상대경로를 적으면 Workbench 루트 기준으로 해석합니다.

도구 경로는 다음 순서로 찾습니다.

1. `Start.ps1` 또는 `Finish.ps1`에 직접 전달한 `-ToolRoot`
2. `UserSettings/sync-tools.json`
3. 구형 `Packages/AgentSessionSync/agentsessionsync.config.psd1`
4. 로컬 형제 폴더 `../AgentSessionVault`

형제 폴더 탐색은 현재 실행에서만 경로를 찾아 쓰며 등록부를 수정하지 않습니다. 공개
`AgentSessionSync` checkout은 실제 대화가 들어갈 private Vault가 아니므로 자동 선택하지 않습니다.
다른 이름의 Vault는 `Register.ps1`로 명시적으로 등록합니다.

패키지가 미등록이면 선택 기능이므로 루트 Start·Finish에서 SKIP으로 보고합니다. 반대로 등록된
ToolRoot의 런처가 없거나 ToolRoot 밖으로 이탈하는 경로를 지정하면 설정 오류로 중단합니다.

## 사용

```powershell
.\Packages\AgentSessionSync\Start.ps1
.\Packages\AgentSessionSync\Finish.ps1
```

루트 `Start.ps1`과 `Finish.ps1`도 설정된 이 패키지를 실행합니다. ToolRoot를 찾지 못하면 선택 기능이므로
`SKIP`으로 보고하지만, 등록된 외부 실행 파일이 없으면 잘못된 설정이므로 전체 실행을 실패시킵니다.

AgentSessionVault의 에이전트 등록, 로컬 애플리케이션 경로, 활성·아카이브·삭제 상태와 보존 정책은 이 어댑터에서 설정하지 않습니다.

## 검사

```powershell
.\Packages\AgentSessionSync\tests\Test-AgentSessionSyncConnector.ps1
```

테스트는 임시 ToolRoot만 사용하며 실제 AgentSessionVault나 앱 세션을 실행하지 않습니다.
