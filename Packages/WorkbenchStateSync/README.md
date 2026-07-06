# WorkbenchStateSync (adapter)

이 패키지는 **외부 상태 동기화 도구**를 호출하는 **얇은 어댑터**입니다. 워크벤치 안에는 `Start.ps1` / `Finish.ps1` 위임 래퍼만 두고, 실제 복사·충돌 처리·시크릿 스캔은 `ToolRoot`의 도구가 수행합니다. 어댑터는 그 도구의 `Launchers\Start.ps1` / `Launchers\Finish.ps1`에 `-WorktreeRoot`(이 워크벤치)를 주입해 호출합니다.

`ToolRoot`는 사용자가 실제로 clone해서 쓰는 자기완결 실사용본 [`MultiAgentWorkbenchStateVault`](https://github.com/cyphen156/MultiAgentWorkbenchStateVault)(도구+실상태 데이터)를 가리킵니다. 공개 [`MultiAgentWorkbenchStateSync`](https://github.com/cyphen156/MultiAgentWorkbenchStateSync)는 같은 도구의 **공개 예시 템플릿**입니다.

동기화 대상 상태(설정·프로젝트 규칙·실제 검토 기록)와 상태 저장소(VaultRoot)는 **외부 도구 쪽에서** 정의·설정합니다.

## 설정

실사용본(Vault)을 clone한 뒤, 그 경로를 `ToolRoot`로 지정합니다.

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

```powershell
@{
    ToolRoot = 'C:\Project\MultiAgent\MultiAgentWorkbenchStateVault'
    StartScript = ''
    FinishScript = ''
}
```

- `ToolRoot`가 없으면 이 어댑터는 **skip**합니다(에러 아님). 도구를 clone하고 경로를 넣으면 활성화됩니다.
- 상태 저장소 경로(VaultRoot)와 동기화 범위는 `ToolRoot`의 외부 도구 config에서 설정합니다.
- `workbenchstatesync.config.psd1`과 루트 `WorkbenchStateSync.local.psd1`은 gitignore 대상입니다.

## 사용

```powershell
.\Packages\WorkbenchStateSync\Start.ps1    # 상태 저장소 -> 워크트리 (외부 도구 위임)
.\Packages\WorkbenchStateSync\Finish.ps1   # 워크트리 -> 상태 저장소 (외부 도구 위임)
```

루트 `Start.ps1` / `Finish.ps1`는 `Packages/` 아래 외부 sync 어댑터를 한 번에 실행하는데, 이 패키지도 거기 포함됩니다(폴더에 있는 것 자체가 등록). 프로젝트 미러 갱신은 별개이며 `Packages\ProjectSync\Sync.ps1`입니다.

작업표시줄 고정용 `.lnk`는 워크벤치 루트의 `Launchers/Create-Shortcuts.ps1`로 한곳에서 생성합니다.
