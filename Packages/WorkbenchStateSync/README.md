# WorkbenchStateSync (adapter)

이 패키지는 **외부 독립 도구** [`MultiAgentWorkbenchStateSync`](https://github.com/cyphen156/MultiAgentWorkbenchStateSync)를 호출하는 **얇은 어댑터**입니다.

MultiAgentCrossReview는 이 동기화 도구를 **소유하지 않습니다.** 실제 구현(엔진)은 외부 레포가 canonical이고, 워크벤치 안에는 `Start.ps1` / `Finish.ps1` 위임 래퍼만 둡니다. 어댑터는 외부 도구에 `-WorktreeRoot`(이 워크벤치)를 주입해 호출합니다.

동기화 대상 상태(설정·프로젝트 규칙·실제 검토 기록)와 상태 저장소(VaultRoot)는 **외부 도구 쪽에서** 정의·설정합니다.

## 설정

외부 도구를 clone한 뒤, 그 경로를 `ToolRoot`로 지정합니다.

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

```powershell
@{
    ToolRoot = 'D:\Tools\MultiAgentWorkbenchStateSync'
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

루트 `Start.ps1` / `Finish.ps1`는 `Packages/` 아래 외부 sync 어댑터를 한 번에 실행하는데, 이 패키지도 거기 포함됩니다(폴더에 있는 것 자체가 등록). 프로젝트 미러 갱신은 별개이며 루트 `ProjectSync/Start.ps1`입니다.
